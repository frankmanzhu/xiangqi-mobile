#include "PikafishBridge.h"

#include <cassert>
#include <cstring>
#include <iostream>

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
    if (!pf_engine_set_position(engine, start_fen, nullptr, 0, &error))
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
    std::cout << "Pikafish " << pf_engine_revision() << " bestmove " << best_move << '\n';
    pf_engine_destroy(engine);
    return 0;
}
