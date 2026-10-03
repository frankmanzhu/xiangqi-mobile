#include "attacks.h"
#include "position.h"
#include "movegen.h"
#include "uci.h"
#include <algorithm>
#include <iostream>
#include <sstream>
#include <vector>

int main() {
    Stockfish::Attacks::init();
    Stockfish::Position::init();
    std::string line;
    size_t count = 0;
    while (std::getline(std::cin, line)) {
        const auto tab = line.find('\t');
        if (tab == std::string::npos) return 1;
        Stockfish::Position position;
        Stockfish::StateInfo state{};
        const auto fen = line.substr(0, tab);
        if (auto error = position.set(fen, &state)) {
            std::cerr << "Engine rejected Swift position " << fen << ": " << error->what() << '\n';
            return 2;
        }
        std::vector<std::string> actual, expected;
        for (const auto &move : Stockfish::MoveList<Stockfish::LEGAL>(position))
            actual.push_back(Stockfish::UCIEngine::move(move));
        std::sort(actual.begin(), actual.end());
        std::istringstream input(line.substr(tab + 1));
        std::string move;
        while (input >> move) expected.push_back(move);
        if (actual != expected) {
            std::cerr << "Legal-move divergence at " << fen << '\n';
            std::cerr << "Swift:";
            for (const auto &m : expected) std::cerr << ' ' << m;
            std::cerr << "\nPikafish:";
            for (const auto &m : actual) std::cerr << ' ' << m;
            std::cerr << '\n';
            return 3;
        }
        ++count;
    }
    if (!count) return 4;
    std::cout << "Swift/Pikafish legal moves agree at " << count << " sampled positions.\n";
}
