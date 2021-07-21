@enum TerminationStatus OPTIMAL INFEASIBLE INF_OR_UNBOUNDED EARLY_TERMINATION NOT_OPTIMIZED

mutable struct Result
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Vector{Float64}
    termination_status::TerminationStatus
    total_node_count::Int
    total_simplex_iters::Int
    total_elapsed_time_sec::Float64
    total_model_builds::Int
    total_warm_starts::Int

    function Result()
        return new(Inf, -Inf, Float64[], NOT_OPTIMIZED, 0, 0, 0, 0, 0)
    end
end

function Result(state::CurrentState, config::AlgorithmConfig)
    update_dual_bound!(state)
    result = Result()
    result.primal_bound = state.primal_bound
    result.dual_bound = state.dual_bound
    copy!(result.best_solution, state.best_solution)
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
    result.total_elapsed_time_sec = state.total_elapsed_time_sec
    result.total_model_builds = state.total_model_builds
    result.total_warm_starts = state.total_warm_starts
    return result
end

@enum NodeResultStatus NOT_SOLVED PRUNED_BY_PARENT_BOUND OPTIMAL_LP INFEASIBLE_LP UNBOUNDED_LP

mutable struct NodeResult
    status::NodeResultStatus
    cost::Float64
    x::Vector{Float64}
    simplex_iters::Int
    depth::Int
    int_infeas::Int
    branching_variable::BoundUpdate
    parent_cost::Float64
    branch_var_fractional::Float64

    function NodeResult(node::Node)
        node_result = new()
        node_result.status = NOT_SOLVED
        node_result.cost = NaN
        node_result.simplex_iters = 0
        node_result.depth = node.depth
        node_result.int_infeas = 0
        node_result.branching_variable = node.branching_variable
        node_result.parent_cost = node.dual_bound
        node_result.branch_var_fractional = node.branch_var_fractional
        return node_result
    end
    function NodeResult(
        status::NodeResultStatus,
        cost::Float64,
        x::Vector{Float64},
        simplex_iters::Int,
        depth::Int,
        int_infeas::Int,
    )
        return new(status, cost, x, simplex_iters, depth, int_infeas, branching_variable = NaN,
                   parent_cost = -Inf, branch_var_fractional = NaN)
    end
end
