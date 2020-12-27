@enum TerminationStatus OPTIMAL INFEASIBLE INF_OR_UNBOUNDED EARLY_TERMINATION NOT_OPTIMIZED

mutable struct Result
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Dict{VI,Float64}
    termination_status::TerminationStatus
    total_node_count::Int
    total_simplex_iters::Int
    timings::TimerOutputs.TimerOutput

    function Result()
        return new(
            Inf,
            -Inf,
            Dict{VI,Float64}(),
            NOT_OPTIMIZED,
            0,
            0,
            TimerOutputs.TimerOutput(),
        )
    end
end

function Result(state::CurrentState, config::AlgorithmConfig)
    result = Result()
    result.primal_bound = state.primal_bound
    result.dual_bound = state.dual_bound
    for (k, v) in state.best_solution
        result.best_solution[k] = v
    end
    if state.primal_bound == state.dual_bound == Inf
        result.termination_status = INFEASIBLE
    elseif state.primal_bound == -Inf
        result.termination_status = INF_OR_UNBOUNDED
    elseif _optimality_gap(state.primal_bound, state.dual_bound) <=
           config.gap_tol
        result.termination_status = OPTIMAL
    else
        result.termination_status = EARLY_TERMINATION
    end
    result.total_node_count = state.total_node_count
    result.total_simplex_iters = state.total_simplex_iters
    return result
end
