#include "PikafishBridge.h"

#include <cassert>
#include <cstring>
#include <iostream>
#include <vector>

void expect_rules(const char *fen, std::vector<const char *> moves, int outcome, int reason) {
    PFEngineError error{};
    PFRuleResult result{};
    if (!pf_rules_result(fen, moves.data(), moves.size(), &result, &error)
        || result.outcome != outcome || result.reason != reason)
    {
        std::cerr << "Rules fixture failed: " << fen << " expected " << outcome << '/' << reason
                  << " got " << result.outcome << '/' << result.reason << ' ' << error.message << '\n';
        std::exit(20);
    }
}

int main(int argc, char **argv) {
    assert(argc == 2);
    PFEngineError error{};
    PFPikafishSession *engine = pf_engine_create(argv[1], &error);
    if (engine == nullptr)
    {
        std::cerr << error.message << '\n';
        return 1;
    }

    constexpr const char *start_fen =
      "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1";
    expect_rules(start_fen, {}, 0, 0);
    expect_rules(start_fen, {"b0c2", "b9c7", "c2b0", "c7b9"}, 0, 0);
    expect_rules(start_fen, {"b0c2", "b9c7", "c2b0", "c7b9",
                             "b0c2", "b9c7", "c2b0", "c7b9"}, 1, 3);
    constexpr const char *checking_fen = "4k4/9/4R4/9/9/9/9/9/9/5K3 b - - 0 1";
    expect_rules(checking_fen, {"e9d9", "e7d7", "d9e9", "d7e7",
                                "e9d9", "e7d7", "d9e9", "d7e7"}, 3, 3);
    expect_rules(checking_fen, {"e9d9", "e7f7", "d9e9", "f7e7",
                                "e9d9", "e7f7", "d9e9", "f7e7"}, 1, 3);
    expect_rules("4k4/9/9/3n5/3R5/9/9/9/9/5K3 b - - 0 1",
                 {"d6f7", "d5f5", "f7d6", "f5d5",
                  "d6f7", "d5f5", "f7d6", "f5d5"}, 3, 3);
    expect_rules("4k4/3RRP3/9/9/9/9/9/9/9/3K5 b - - 0 1", {}, 2, 1);
    expect_rules("4k4/3R1R3/9/9/9/9/9/9/9/3K5 b - - 0 1", {}, 2, 2);
    expect_rules("4k4/9/9/9/9/9/9/9/9/5K3 w - - 0 1", {}, 1, 3);
    expect_rules("rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 119 1",
                 {"b0c2"}, 1, 3);
    PFRuleResult invalid_result{};
    const char *invalid_history[] = {"a3a2"};
    assert(!pf_rules_result(start_fen, invalid_history, 1, &invalid_result, &error));
    assert(error.code == 14);
    std::cout << "Rules fixtures passed: repetition, perpetual check/chase, mixed checking, mate, stalemate, insufficient material, illegal history.\n";
    const char *first_history[] = {"a3a4"};
    if (!pf_engine_set_position(engine, start_fen, first_history, 1, &error))
    {
        std::cerr << error.message << '\n';
        return 2;
    }

    char best_move[6]{};
    if (!pf_engine_best_move(engine, 100, 0, 0, best_move, &error))
    {
        std::cerr << error.message << '\n';
        return 3;
    }
    assert(std::strlen(best_move) == 4);
    const char *second_history[] = {"a3a4", best_move};
    char suggested_move[6]{};
    if (!pf_engine_set_position(engine, start_fen, second_history, 2, &error)
        || !pf_engine_best_move(engine, 100, 0, 0, suggested_move, &error))
    {
        std::cerr << error.message << '\n';
        return 4;
    }
    assert(std::strlen(suggested_move) == 4);
    std::cout << "Pikafish " << pf_engine_revision() << " opponent " << best_move
              << " suggestion " << suggested_move << '\n';
    pf_engine_destroy(engine);
    return 0;
}
