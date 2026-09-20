#include "PikafishBridge.h"

#include <algorithm>
#include <condition_variable>
#include <cstring>
#include <filesystem>
#include <memory>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

#include "attacks.h"
#include "engine.h"
#include "position.h"
#include "tune.h"

namespace {

constexpr const char *Revision = "6a59ee2f7b105bff64d9efc2692591107787e2b1";

void clear_error(PFEngineError *error) {
    if (error == nullptr)
        return;
    error->code       = 0;
    error->message[0] = '\0';
}

void set_error(PFEngineError *error, int32_t code, const std::string& message) {
    if (error == nullptr)
        return;
    error->code = code;
    std::strncpy(error->message, message.c_str(), sizeof(error->message) - 1);
    error->message[sizeof(error->message) - 1] = '\0';
}

void initialize_pikafish() {
    static std::once_flag flag;
    std::call_once(flag, [] {
        Stockfish::Attacks::init();
        Stockfish::Position::init();
    });
}

void set_option(Stockfish::OptionsMap& options,
                const std::string& name,
                const std::string& value) {
    std::istringstream command("name " + name + " value " + value);
    options.setoption(command);
}

}  // namespace

struct PFPikafishSession {
    std::unique_ptr<Stockfish::Engine> engine;
    std::mutex mutex;
    std::condition_variable search_finished;
    std::string best_move;
    bool searching = false;
};

PFPikafishSession *pf_engine_create(const char *network_path, PFEngineError *error) {
    clear_error(error);
    if (network_path == nullptr || network_path[0] == '\0')
    {
        set_error(error, 1, "Pikafish network path is empty.");
        return nullptr;
    }

    const std::filesystem::path path(network_path);
    std::error_code file_error;
    if (!std::filesystem::is_regular_file(path, file_error))
    {
        set_error(error, 2, "Pikafish network file is missing.");
        return nullptr;
    }

    try
    {
        initialize_pikafish();
        auto session    = std::make_unique<PFPikafishSession>();
        session->engine = std::make_unique<Stockfish::Engine>(path);
        set_option(session->engine->get_options(), "NumaPolicy", "none");
        set_option(session->engine->get_options(), "Threads", "1");
        set_option(session->engine->get_options(), "Hash", "32");
        set_option(session->engine->get_options(), "MultiPV", "1");
        set_option(session->engine->get_options(), "EvalFile", path.string());
        Stockfish::Tune::init(session->engine->get_options());

        auto *raw = session.get();
        raw->engine->set_on_bestmove([raw](std::string_view bestmove, std::string_view) {
            {
                std::lock_guard lock(raw->mutex);
                raw->best_move.assign(bestmove);
                raw->searching = false;
            }
            raw->search_finished.notify_all();
        });
        raw->engine->set_on_update_no_moves([](const auto&) {});
        raw->engine->set_on_update_full([](const auto&) {});
        raw->engine->set_on_iter([](const auto&) {});
        raw->engine->set_on_start([] {});
        raw->engine->set_on_verify_network([](std::string_view) {});
        return session.release();
    }
    catch (const std::exception& exception)
    {
        set_error(error, 3, std::string("Pikafish initialization failed: ") + exception.what());
        return nullptr;
    }
}

void pf_engine_destroy(PFPikafishSession *session) {
    if (session == nullptr)
        return;
    session->engine->stop();
    session->engine->wait_for_search_finished();
    delete session;
}

bool pf_engine_set_position(PFPikafishSession *session,
                            const char *fen,
                            const char *const *moves,
                            size_t move_count,
                            PFEngineError *error) {
    clear_error(error);
    if (session == nullptr || fen == nullptr)
    {
        set_error(error, 4, "Pikafish session or FEN is missing.");
        return false;
    }

    try
    {
        session->engine->stop();
        session->engine->wait_for_search_finished();
        std::vector<std::string> move_list;
        move_list.reserve(move_count);
        for (size_t index = 0; index < move_count; ++index)
        {
            if (moves == nullptr || moves[index] == nullptr)
            {
                set_error(error, 5, "Move history contains an empty move.");
                return false;
            }
            move_list.emplace_back(moves[index]);
        }
        if (auto position_error = session->engine->set_position(fen, move_list))
        {
            set_error(error, 6, position_error->what());
            return false;
        }
        return true;
    }
    catch (const std::exception& exception)
    {
        set_error(error, 7, std::string("Could not set Pikafish position: ") + exception.what());
        return false;
    }
}

bool pf_engine_best_move(PFPikafishSession *session,
                         int32_t move_time_ms,
                         uint64_t node_limit,
                         int32_t depth_limit,
                         char output[6],
                         PFEngineError *error) {
    clear_error(error);
    if (session == nullptr || output == nullptr)
    {
        set_error(error, 8, "Pikafish session or output buffer is missing.");
        return false;
    }

    try
    {
        Stockfish::Search::LimitsType limits;
        limits.startTime = Stockfish::now();
        limits.movetime = std::max<int32_t>(move_time_ms, 1);
        limits.nodes    = node_limit;
        limits.depth    = std::max<int32_t>(depth_limit, 0);

        {
            std::lock_guard lock(session->mutex);
            session->best_move.clear();
            session->searching = true;
        }
        session->engine->go(limits);

        std::unique_lock lock(session->mutex);
        session->search_finished.wait(lock, [session] { return !session->searching; });
        const std::string best_move = session->best_move;
        lock.unlock();
        session->engine->wait_for_search_finished();

        if (best_move.size() != 4)
        {
            set_error(error, 9, "Pikafish did not return a legal best move.");
            return false;
        }
        std::memset(output, 0, 6);
        std::memcpy(output, best_move.data(), 4);
        return true;
    }
    catch (const std::exception& exception)
    {
        {
            std::lock_guard lock(session->mutex);
            session->searching = false;
        }
        set_error(error, 10, std::string("Pikafish search failed: ") + exception.what());
        return false;
    }
}

void pf_engine_stop(PFPikafishSession *session) {
    if (session != nullptr)
        session->engine->stop();
}

const char *pf_engine_revision(void) { return Revision; }
