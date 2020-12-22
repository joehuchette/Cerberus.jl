@enum TerminationStatus OPTIMAL INFEASIBLE UNBOUNDED EARLY_TERMINATION NOT_OPTIMIZED

mutable struct Result
    primal_bound::Float64
    dual_bound::Float64
    termination_status::TerminationStatus
    node_count::Int
    simplex_iters::Int
    timings::TimerOutputs.TimerOutput

    Result() = new(Inf, -Inf, NOT_OPTIMIZED, 0, 0, TimerOutputs.TimerOutput())
end

function Result(state::CurrentState, config::AlgorithmConfig)
    result = Result()
    result.primal_bound = state.primal_bound
    result.dual_bound = state.dual_bound
    if state.primal_bound == state.dual_bound == Inf
        result.termination_status = INFEASIBLE
    elseif state.primal_bound == -Inf
        result.termination_status = UNBOUNDED
    elseif _optimality_gap(state) <= config.gap_tol
        result.termination_status = OPTIMAL
    else
        result.termination_status = EARLY_TERMINATION
    end
    result.node_count = state.enumerated_node_count
    result.simplex_iters = state.total_simplex_iters
    return result
end
