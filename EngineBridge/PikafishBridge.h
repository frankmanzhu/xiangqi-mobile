#ifndef PIKAFISH_BRIDGE_H
#define PIKAFISH_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PFPikafishSession PFPikafishSession;

typedef struct PFEngineError {
    int32_t code;
    char message[512];
} PFEngineError;

// outcome: 0 ongoing, 1 draw, 2 red wins, 3 black wins.
// reason: 0 ongoing, 1 checkmate, 2 stalemate, 3 computer-rule adjudication.
typedef struct PFRuleResult {
    int32_t outcome;
    int32_t reason;
} PFRuleResult;

// Replays full history without loading NNUE or starting an engine search.
bool pf_rules_result(const char *fen, const char *const *moves, size_t move_count,
                     PFRuleResult *result, PFEngineError *error);

PFPikafishSession *pf_engine_create(const char *network_path, PFEngineError *error);
void pf_engine_destroy(PFPikafishSession *session);

bool pf_engine_set_position(
    PFPikafishSession *session,
    const char *fen,
    const char *const *moves,
    size_t move_count,
    PFEngineError *error
);

bool pf_engine_best_move(
    PFPikafishSession *session,
    int32_t move_time_ms,
    uint64_t node_limit,
    int32_t depth_limit,
    char output[6],
    PFEngineError *error
);

void pf_engine_stop(PFPikafishSession *session);
const char *pf_engine_revision(void);

#ifdef __cplusplus
}
#endif

#endif
