import SwiftUI

/// Display names for the dataset's category identifiers, which are Chinese
/// strings in the source corpus and must not be used as UI text directly.
enum CCPDCategory {
    static func titleKey(_ category: String) -> LocalizedKey? {
        switch category {
        case "中局": L10n.Learn.Category.middlegames
        case "全盤戰術": L10n.Learn.Category.fullGameTactics
        case "對局": L10n.Learn.Category.games
        case "殘局": L10n.Learn.Category.endgames
        case "殺局_殺法_練習題": L10n.Learn.Category.matingPractice
        case "開局": L10n.Learn.Category.openings
        default: nil
        }
    }

    /// The translated name, or the raw identifier when the corpus grows a
    /// category this build does not yet name.
    static func title(_ category: String, _ l10n: Localizer) -> String {
        guard let key = titleKey(category) else { return category }
        return l10n(key)
    }

    static func icon(_ category: String) -> String {
        switch category {
        case "中局": "square.grid.3x3.middle.filled"
        case "全盤戰術": "scope"
        case "對局": "list.number"
        case "殘局": "flag.checkered"
        case "殺局_殺法_練習題": "target"
        case "開局": "arrow.triangle.branch"
        default: "books.vertical"
        }
    }

    static let matingPracticeID = "殺局_殺法_練習題"
}

private enum LearningMatchSubcategory: String, CaseIterable, Identifiable {
    case all
    case ccpdMaster
    case ccpdComputer
    case wxf
    case dongping

    var id: String { rawValue }

    var sourcePrefix: String? {
        switch self {
        case .all: nil
        case .ccpdMaster: "對局/大師對局/"
        case .ccpdComputer: "對局/電腦對局/"
        case .wxf: "ICCS/WXF/"
        case .dongping: "ICCS/Dongping/"
        }
    }

    var titleKey: LocalizedKey {
        switch self {
        case .all: L10n.Learn.Subcategory.allMatches
        case .ccpdMaster: L10n.Learn.Subcategory.ccpdMasterMatches
        case .ccpdComputer: L10n.Learn.Subcategory.ccpdComputerMatches
        case .wxf: L10n.Learn.Subcategory.wxfMatches
        case .dongping: L10n.Learn.Subcategory.dongpingMatches
        }
    }
}

private enum LearningLibraryProvider {
    static func load() throws -> LearningLibraryStore {
        guard let url = Bundle.main.url(forResource: "ccpd", withExtension: "sqlite3") else {
            throw CCPDLibraryError.databaseUnavailable("The bundled learning library is missing.")
        }
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CCPDLibraryError.databaseUnavailable("The user learning library location is unavailable.")
        }
        let userURL = applicationSupport
            .appendingPathComponent("XiangqiMobile", isDirectory: true)
            .appendingPathComponent("user-games.sqlite3")
        return try LearningLibraryStore(bundledDatabaseURL: url, userDatabaseURL: userURL)
    }
}

struct LearningHomeView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.l10n) private var l10n
    @State private var categories: [CCPDCategorySummary] = []
    @State private var metadata: [String: String] = [:]
    @State private var errorMessage: UserFacingError?
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Learn.Dataset.title, l10n)
                        .font(.title2.bold())
                    Text(L10n.Learn.Dataset.subtitle, l10n)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if isLoading {
                HStack { Spacer(); ProgressView(l10n(L10n.Learn.loadingLibrary)); Spacer() }
            } else if let errorMessage {
                ContentUnavailableView(
                    l10n(L10n.Learn.libraryUnavailable),
                    systemImage: "books.vertical",
                    description: Text(verbatim: errorMessage.text(l10n))
                )
            } else {
                Section(l10n(L10n.Learn.Section.browse)) {
                    ForEach(categories, id: \.id) { category in
                        Button { app.path.append(.learningCategory(category.id)) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: CCPDCategory.icon(category.id))
                                    .frame(width: 30)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(verbatim: CCPDCategory.title(category.id, l10n))
                                        .font(.headline)
                                    Text(
                                        L10n.Learn.recordCount,
                                        l10n,
                                        category.recordCount.formatted(.number.locale(l10n.locale))
                                    )
                                    .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(l10n(L10n.Common.source)) {
                    LabeledContent(l10n(L10n.Learn.license), value: metadata["license"] ?? "CC BY 4.0")
                    LabeledContent(
                        l10n(L10n.Learn.validatedRecords),
                        value: metadata["imported_files"] ?? l10n(L10n.Common.emptyValue)
                    )
                    if let revision = metadata["source_revision"] {
                        LabeledContent(
                            l10n(L10n.Learn.datasetRevision),
                            value: String(revision.prefix(10))
                        )
                    }
                    Text(L10n.Learn.Dataset.note, l10n)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(l10n(L10n.Learn.title))
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let library = try LearningLibraryProvider.load()
            async let loadedCategories = Task.detached { try library.categories() }.value
            async let loadedMetadata = Task.detached { try library.metadata() }.value
            categories = try await loadedCategories
            metadata = try await loadedMetadata
        } catch {
            errorMessage = UserFacingError(error)
        }
    }

}

struct LearningLibraryView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.l10n) private var l10n
    let category: String
    @State private var records: [CCPDRecordSummary] = []
    @State private var query = ""
    @State private var subcategory: LearningMatchSubcategory = .all
    @State private var errorMessage: UserFacingError?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading && records.isEmpty {
                ProgressView(l10n(L10n.Learn.loadingRecords))
            } else if let errorMessage, records.isEmpty {
                ContentUnavailableView(
                    l10n(L10n.Learn.couldNotLoadRecords),
                    systemImage: "exclamationmark.triangle",
                    description: Text(verbatim: errorMessage.text(l10n))
                )
            } else {
                List {
                    if category == "對局" {
                        Section {
                            Picker(l10n(L10n.Learn.Subcategory.title), selection: $subcategory) {
                                ForEach(LearningMatchSubcategory.allCases) { option in
                                    Text(option.titleKey, l10n)
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        } header: {
                            Text(L10n.Learn.Subcategory.title, l10n)
                        }
                    }

                    if records.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        ForEach(records) { record in
                            Button {
                                app.path.append(
                                    category == CCPDCategory.matingPracticeID
                                        ? .practiceRecord(record.id)
                                        : .studyRecord(record.id)
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(verbatim: record.event.nilIfEmpty ?? record.sourcePath)
                                        .font(.headline).foregroundStyle(.primary).lineLimit(2)
                                    HStack(spacing: 6) {
                                        if let red = record.red.nilIfEmpty { Text(verbatim: red) }
                                        if record.red.nilIfEmpty != nil || record.black.nilIfEmpty != nil {
                                            Text(L10n.Common.nameSeparator, l10n)
                                        }
                                        if let black = record.black.nilIfEmpty { Text(verbatim: black) }
                                    }
                                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    HStack {
                                        if let date = record.dateText.nilIfEmpty { Text(verbatim: date) }
                                        if let ecco = record.ecco.nilIfEmpty { Text(verbatim: ecco) }
                                        Text(L10n.Learn.plyCount, l10n, record.moveCount)
                                    }
                                    .font(.caption).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("ccpd-record-\(record.id)")
                        }
                    }
                }
            }
        }
        .navigationTitle(CCPDCategory.title(category, l10n))
        .searchable(text: $query, prompt: l10n(L10n.Learn.searchPrompt))
        .task(id: "\(query)|\(subcategory.rawValue)") {
            try? await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 250))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let library = try LearningLibraryProvider.load()
            let category = category
            let query = query
            let sourcePrefix = subcategory.sourcePrefix
            records = try await Task.detached {
                try library.records(
                    category: category,
                    matching: query,
                    sourcePrefix: sourcePrefix,
                    limit: 200
                )
            }.value
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError(error)
        }
    }
}

struct CCPDStudyView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.l10n) private var l10n
    let recordID: String
    @State private var record: CCPDRecord?
    @State private var ply = 0
    @State private var errorMessage: UserFacingError?
    @State private var isBookmarked = false
    @State private var recordedCompletion = false

    var body: some View {
        Group {
            if let record {
                VStack(spacing: 0) {
                    ReadOnlyBoardView(
                        position: currentPosition(record),
                        orientation: .red,
                        lastMove: ply > 0 ? Move(uci: record.moves[ply - 1].uci) : nil
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    List {
                        Section {
                            Text(verbatim: record.summary.event.nilIfEmpty ?? record.summary.sourcePath)
                                .font(.headline)
                            if let red = record.summary.red.nilIfEmpty {
                                LabeledContent(l10n(L10n.Side.red), value: red)
                            }
                            if let black = record.summary.black.nilIfEmpty {
                                LabeledContent(l10n(L10n.Side.black), value: black)
                            }
                            if let result = record.summary.result.nilIfEmpty {
                                LabeledContent(l10n(L10n.Common.result), value: result)
                            }
                            if let ecco = record.summary.ecco.nilIfEmpty {
                                LabeledContent(l10n(L10n.Learn.ecco), value: ecco)
                            }
                        }
                        Section(l10n(L10n.Common.moves)) {
                            ForEach(record.moves, id: \.ply) { move in
                                Button { ply = move.ply } label: {
                                    HStack {
                                        Text(L10n.Study.moveNumber, l10n, move.ply)
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                            .frame(width: 42, alignment: .trailing)
                                        Text(verbatim: move.sourceNotation)
                                        Spacer()
                                        Text(verbatim: move.uci)
                                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(ply == move.ply ? Color.accentColor.opacity(0.12) : nil)
                            }
                        }
                        Section(l10n(L10n.Common.source)) {
                            Text(verbatim: record.summary.sourcePath).font(.caption.monospaced())
                            Text(L10n.Study.attribution, l10n)
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    replayControls(record)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    l10n(L10n.Study.couldNotOpen),
                    systemImage: "exclamationmark.triangle",
                    description: Text(verbatim: errorMessage.text(l10n))
                )
            } else {
                ProgressView(l10n(L10n.Study.opening))
            }
        }
        .navigationTitle(l10n(L10n.Study.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { app.path.append(.practiceRecord(recordID)) } label: {
                    Label(l10n(L10n.Study.practice), systemImage: "target")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await toggleBookmark() } } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(l10n(isBookmarked ? L10n.Study.removeBookmark : L10n.Study.bookmark))
            }
        }
        .task { await load() }
        .onChange(of: ply) { _, newValue in
            Task {
                try? await app.learningProgress.updateLastPly(newValue, for: recordID)
                if let record, newValue == record.moves.count, !recordedCompletion {
                    recordedCompletion = true
                    try? await app.learningProgress.recordCompletion(for: recordID, finalPly: newValue)
                }
            }
        }
    }

    private func replayControls(_ record: CCPDRecord) -> some View {
        HStack {
            Button { ply = max(0, ply - 1) } label: {
                Label(l10n(L10n.Common.previous), systemImage: "chevron.left")
            }
            .disabled(ply == 0)
            Spacer()
            Text(L10n.Study.plyProgress, l10n, ply, record.moves.count).monospacedDigit()
            Spacer()
            Button { ply = min(record.moves.count, ply + 1) } label: {
                Label(l10n(L10n.Common.next), systemImage: "chevron.right")
            }
            .disabled(ply == record.moves.count)
        }
        .padding().background(.bar)
    }

    private func currentPosition(_ record: CCPDRecord) -> Position {
        (try? record.position(afterPly: ply)) ?? (try? Position(fen: record.startingFEN)) ?? .standard
    }

    private func load() async {
        do {
            let library = try LearningLibraryProvider.load()
            let id = recordID
            record = try await Task.detached { try library.record(id: id) }.value
            if let record {
                let progress = try await app.learningProgress.progress(for: id)
                ply = min(progress.lastPly, record.moves.count)
                isBookmarked = progress.isBookmarked
                try await app.learningProgress.recordOpened(id, lastPly: ply)
            } else {
                errorMessage = UserFacingError(L10n.Study.recordMissing)
            }
        } catch {
            errorMessage = UserFacingError(error)
        }
    }

    private func toggleBookmark() async {
        do {
            isBookmarked = try await app.learningProgress.toggleBookmark(for: recordID).isBookmarked
        } catch {
            errorMessage = UserFacingError(error)
        }
    }
}

/// What the puzzle's coaching line should say, held as a value so it can be
/// rendered in whichever language is selected when the view draws.
private enum PuzzleFeedback: Equatable {
    case findBestMove
    case chooseDestination
    case incorrect
    case correct
    case completed
    case hint(String)

    func text(_ l10n: Localizer) -> String {
        switch self {
        case .findBestMove: l10n(L10n.Practice.findBestMove)
        case .chooseDestination: l10n(L10n.Practice.chooseDestination)
        case .incorrect: l10n(L10n.Practice.incorrect)
        case .correct: l10n(L10n.Practice.correct)
        case .completed: l10n(L10n.Practice.completed)
        case .hint(let notation): l10n(L10n.Practice.hintFormat, notation)
        }
    }
}

struct CCPDPuzzleView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.l10n) private var l10n
    let recordID: String
    @State private var record: CCPDRecord?
    @State private var puzzle: CCPDPuzzleSession?
    @State private var selectedSquare: Square?
    @State private var feedback: PuzzleFeedback = .findBestMove
    @State private var errorMessage: UserFacingError?
    @State private var recordedCompletion = false

    private var legalDestinations: Set<Square> {
        guard let puzzle, let selectedSquare else { return [] }
        return Set(puzzle.position.legalMoves().filter { $0.from == selectedSquare }.map(\.to))
    }

    var body: some View {
        Group {
            if let puzzle, let record {
                VStack(spacing: 0) {
                    PracticeBoardView(
                        position: puzzle.position,
                        orientation: puzzle.practiceSide,
                        lastMove: puzzle.lastMove,
                        selectedSquare: selectedSquare,
                        legalDestinations: legalDestinations,
                        onTap: tap
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(verbatim: record.summary.event.nilIfEmpty ?? record.summary.sourcePath)
                            .font(.headline).lineLimit(2)
                        HStack {
                            Text(
                                L10n.Practice.moveProgress,
                                l10n,
                                puzzle.currentPly + 1,
                                record.moves.count
                            )
                            Spacer()
                            Text(L10n.Practice.mistakes, l10n, puzzle.mistakes)
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(verbatim: feedback.text(l10n)).font(.subheadline)
                        HStack {
                            Button(l10n(L10n.Common.hint)) { revealHint() }
                            Spacer()
                            Button(l10n(L10n.Common.restart)) { restart() }
                            Button(l10n(L10n.Practice.studyLine)) { app.path.append(.studyRecord(recordID)) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    l10n(L10n.Practice.couldNotOpen),
                    systemImage: "exclamationmark.triangle",
                    description: Text(verbatim: errorMessage.text(l10n))
                )
            } else {
                ProgressView(l10n(L10n.Practice.opening))
            }
        }
        .navigationTitle(l10n(L10n.Practice.title))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { FeedbackPlayer.shared.prepare() }
        .task { await load() }
    }

    private func tap(_ square: Square) {
        guard var current = puzzle, !current.isComplete else { return }
        if let selectedSquare, legalDestinations.contains(square) {
            do {
                let result = try current.attempt(Move(from: selectedSquare, to: square))
                puzzle = current
                self.selectedSquare = nil
                switch result {
                case .incorrect:
                    feedback = .incorrect
                    FeedbackPlayer.shared.play(.invalidAttempt)
                case .correct:
                    feedback = .correct
                    FeedbackPlayer.shared.play(.move)
                case .completed:
                    feedback = .completed
                    FeedbackPlayer.shared.play(.gameEnd)
                    if !recordedCompletion {
                        recordedCompletion = true
                        Task { try? await app.learningProgress.recordCompletion(for: recordID, finalPly: current.currentPly) }
                    }
                }
                Task { try? await app.learningProgress.updateLastPly(current.currentPly, for: recordID) }
            } catch {
                errorMessage = UserFacingError(error)
            }
            return
        }
        if let piece = current.position.piece(at: square), piece.side == current.position.sideToMove {
            selectedSquare = square
            feedback = .chooseDestination
            FeedbackPlayer.shared.play(.pieceSelected)
        } else {
            selectedSquare = nil
        }
    }

    private func revealHint() {
        guard let puzzle, let expected = puzzle.expectedMove else { return }
        selectedSquare = expected.from
        if let record, puzzle.currentPly < record.moves.count {
            feedback = .hint(record.moves[puzzle.currentPly].sourceNotation)
        }
    }

    private func restart() {
        guard var current = puzzle else { return }
        do {
            try current.restart()
            puzzle = current
            selectedSquare = nil
            recordedCompletion = false
            feedback = .findBestMove
            Task { try? await app.learningProgress.recordOpened(recordID) }
        } catch {
            errorMessage = UserFacingError(error)
        }
    }

    private func load() async {
        do {
            let library = try LearningLibraryProvider.load()
            let id = recordID
            guard let loaded = try await Task.detached(operation: { try library.record(id: id) }).value else {
                errorMessage = UserFacingError(L10n.Study.recordMissing)
                return
            }
            record = loaded
            puzzle = try CCPDPuzzleSession(record: loaded)
            try await app.learningProgress.recordOpened(id)
        } catch {
            errorMessage = UserFacingError(error)
        }
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
