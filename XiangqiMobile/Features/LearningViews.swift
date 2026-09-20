import SwiftUI

private enum BundledCCPDLibrary {
    static func load() throws -> CCPDLibrary {
        guard let url = Bundle.main.url(forResource: "ccpd", withExtension: "sqlite3") else {
            throw CCPDLibraryError.databaseUnavailable("The bundled learning library is missing.")
        }
        let library = CCPDLibrary(databaseURL: url)
        try library.validate()
        return library
    }
}

struct LearningHomeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var categories: [CCPDCategorySummary] = []
    @State private var metadata: [String: String] = [:]
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chinese Chess Practical Dataset")
                        .font(.title2.bold())
                    Text("Study master games, openings, middlegames, endgames, and tactical positions entirely offline.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if isLoading {
                HStack { Spacer(); ProgressView("Loading library…"); Spacer() }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Learning library unavailable",
                    systemImage: "books.vertical",
                    description: Text(errorMessage)
                )
            } else {
                Section("Browse") {
                    ForEach(categories, id: \.id) { category in
                        Button { app.path.append(.learningCategory(category.id)) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon(for: category.id))
                                    .frame(width: 30)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(title(for: category.id)).font(.headline)
                                    Text("\(category.recordCount.formatted()) records")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Source") {
                    LabeledContent("License", value: metadata["license"] ?? "CC BY 4.0")
                    LabeledContent("Validated records", value: metadata["imported_files"] ?? "—")
                    if let revision = metadata["source_revision"] {
                        LabeledContent("Dataset revision", value: String(revision.prefix(10)))
                    }
                    Text("Dataset by Yu-Han Tseng and Bo-Nian Chen. Source records are decoded, converted to UCI, and legality-validated; ambiguous or invalid records are excluded.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Learn")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let library = try BundledCCPDLibrary.load()
            async let loadedCategories = Task.detached { try library.categories() }.value
            async let loadedMetadata = Task.detached { try library.metadata() }.value
            categories = try await loadedCategories
            metadata = try await loadedMetadata
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func title(for category: String) -> LocalizedStringKey {
        switch category {
        case "中局": "Middlegames"
        case "全盤戰術": "Full-game tactics"
        case "對局": "Games"
        case "殘局": "Endgames"
        case "殺局_殺法_練習題": "Mating practice"
        case "開局": "Openings"
        default: LocalizedStringKey(category)
        }
    }

    private func icon(for category: String) -> String {
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
}

struct LearningLibraryView: View {
    @EnvironmentObject private var app: AppModel
    let category: String
    @State private var records: [CCPDRecordSummary] = []
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading && records.isEmpty {
                ProgressView("Loading records…")
            } else if let errorMessage, records.isEmpty {
                ContentUnavailableView("Could not load records", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if records.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(records) { record in
                    Button {
                        app.path.append(category == "殺局_殺法_練習題" ? .practiceRecord(record.id) : .studyRecord(record.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.event.nilIfEmpty ?? record.sourcePath)
                                .font(.headline).foregroundStyle(.primary).lineLimit(2)
                            HStack(spacing: 6) {
                                if let red = record.red.nilIfEmpty { Text(red) }
                                if record.red.nilIfEmpty != nil || record.black.nilIfEmpty != nil { Text("–") }
                                if let black = record.black.nilIfEmpty { Text(black) }
                            }
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            HStack {
                                if let date = record.dateText.nilIfEmpty { Text(date) }
                                if let ecco = record.ecco.nilIfEmpty { Text(ecco) }
                                Text("\(record.moveCount) plies")
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
        .navigationTitle(Text(categoryTitle))
        .searchable(text: $query, prompt: "Player, event, or ECCO")
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 250))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private var categoryTitle: LocalizedStringKey {
        switch category {
        case "中局": "Middlegames"
        case "全盤戰術": "Full-game tactics"
        case "對局": "Games"
        case "殘局": "Endgames"
        case "殺局_殺法_練習題": "Mating practice"
        case "開局": "Openings"
        default: LocalizedStringKey(category)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let library = try BundledCCPDLibrary.load()
            let category = category
            let query = query
            records = try await Task.detached {
                try library.records(category: category, matching: query, limit: 200)
            }.value
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

struct CCPDStudyView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage("theme") private var themeRaw = ThemeID.classic.rawValue
    let recordID: String
    @State private var record: CCPDRecord?
    @State private var ply = 0
    @State private var errorMessage: String?
    @State private var isBookmarked = false
    @State private var recordedCompletion = false

    var body: some View {
        Group {
            if let record {
                VStack(spacing: 0) {
                    ReadOnlyBoardView(
                        position: currentPosition(record),
                        orientation: .red,
                        palette: .palette(for: ThemeID(rawValue: themeRaw) ?? .classic),
                        lastMove: ply > 0 ? Move(uci: record.moves[ply - 1].uci) : nil
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    List {
                        Section {
                            Text(record.summary.event.nilIfEmpty ?? record.summary.sourcePath).font(.headline)
                            if let red = record.summary.red.nilIfEmpty { LabeledContent("Red", value: red) }
                            if let black = record.summary.black.nilIfEmpty { LabeledContent("Black", value: black) }
                            if let result = record.summary.result.nilIfEmpty { LabeledContent("Result", value: result) }
                            if let ecco = record.summary.ecco.nilIfEmpty { LabeledContent("ECCO", value: ecco) }
                        }
                        Section("Moves") {
                            ForEach(record.moves, id: \.ply) { move in
                                Button { ply = move.ply } label: {
                                    HStack {
                                        Text("\(move.ply).")
                                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
                                        Text(move.sourceNotation)
                                        Spacer()
                                        Text(move.uci).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(ply == move.ply ? Color.accentColor.opacity(0.12) : nil)
                            }
                        }
                        Section("Source") {
                            Text(record.summary.sourcePath).font(.caption.monospaced())
                            Text("CCPD · CC BY 4.0 · Modified by decoding, notation normalization, and legality validation.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    replayControls(record)
                }
            } else if let errorMessage {
                ContentUnavailableView("Could not open record", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView("Opening record…")
            }
        }
        .navigationTitle("Study")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { app.path.append(.practiceRecord(recordID)) } label: {
                    Label("Practice", systemImage: "target")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await toggleBookmark() } } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")
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
            Button { ply = max(0, ply - 1) } label: { Label("Previous", systemImage: "chevron.left") }
                .disabled(ply == 0)
            Spacer()
            Text("\(ply) / \(record.moves.count)").monospacedDigit()
            Spacer()
            Button { ply = min(record.moves.count, ply + 1) } label: { Label("Next", systemImage: "chevron.right") }
                .disabled(ply == record.moves.count)
        }
        .padding().background(.bar)
    }

    private func currentPosition(_ record: CCPDRecord) -> Position {
        (try? record.position(afterPly: ply)) ?? (try? Position(fen: record.startingFEN)) ?? .standard
    }

    private func load() async {
        do {
            let library = try BundledCCPDLibrary.load()
            let id = recordID
            record = try await Task.detached { try library.record(id: id) }.value
            if let record {
                let progress = try await app.learningProgress.progress(for: id)
                ply = min(progress.lastPly, record.moves.count)
                isBookmarked = progress.isBookmarked
                try await app.learningProgress.recordOpened(id, lastPly: ply)
            } else {
                errorMessage = "The record is not present in this library."
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func toggleBookmark() async {
        do {
            isBookmarked = try await app.learningProgress.toggleBookmark(for: recordID).isBookmarked
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

struct CCPDPuzzleView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage("theme") private var themeRaw = ThemeID.classic.rawValue
    let recordID: String
    @State private var record: CCPDRecord?
    @State private var puzzle: CCPDPuzzleSession?
    @State private var selectedSquare: Square?
    @State private var feedback: LocalizedStringKey = "Find the best move."
    @State private var errorMessage: String?
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
                        palette: .palette(for: ThemeID(rawValue: themeRaw) ?? .classic),
                        lastMove: puzzle.lastMove,
                        selectedSquare: selectedSquare,
                        legalDestinations: legalDestinations,
                        onTap: tap
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(record.summary.event.nilIfEmpty ?? record.summary.sourcePath)
                            .font(.headline).lineLimit(2)
                        HStack {
                            Text("Move \(puzzle.currentPly + 1) of \(record.moves.count)")
                            Spacer()
                            Text("Mistakes: \(puzzle.mistakes)")
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(feedback).font(.subheadline)
                        HStack {
                            Button("Hint") { revealHint() }
                            Spacer()
                            Button("Restart") { restart() }
                            Button("Study line") { app.path.append(.studyRecord(recordID)) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
                }
            } else if let errorMessage {
                ContentUnavailableView("Could not open practice", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView("Opening practice…")
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
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
                    feedback = "Not the recorded move. Try again."
                case .correct:
                    feedback = "Correct. The recorded reply has been played."
                case .completed:
                    feedback = "Line complete. Well done."
                    if !recordedCompletion {
                        recordedCompletion = true
                        Task { try? await app.learningProgress.recordCompletion(for: recordID, finalPly: current.currentPly) }
                    }
                }
                Task { try? await app.learningProgress.updateLastPly(current.currentPly, for: recordID) }
            } catch {
                errorMessage = String(describing: error)
            }
            return
        }
        if let piece = current.position.piece(at: square), piece.side == current.position.sideToMove {
            selectedSquare = square
            feedback = "Choose a destination."
        } else {
            selectedSquare = nil
        }
    }

    private func revealHint() {
        guard let puzzle, let expected = puzzle.expectedMove else { return }
        selectedSquare = expected.from
        if let record, puzzle.currentPly < record.moves.count {
            feedback = LocalizedStringKey("Hint: \(record.moves[puzzle.currentPly].sourceNotation)")
        }
    }

    private func restart() {
        guard var current = puzzle else { return }
        do {
            try current.restart()
            puzzle = current
            selectedSquare = nil
            recordedCompletion = false
            feedback = "Find the best move."
            Task { try? await app.learningProgress.recordOpened(recordID) }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func load() async {
        do {
            let library = try BundledCCPDLibrary.load()
            let id = recordID
            guard let loaded = try await Task.detached(operation: { try library.record(id: id) }).value else {
                errorMessage = "The record is not present in this library."
                return
            }
            record = loaded
            puzzle = try CCPDPuzzleSession(record: loaded)
            try await app.learningProgress.recordOpened(id)
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
