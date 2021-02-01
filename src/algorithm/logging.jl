function _log_preamble(
    fm::DMIPFormulation,
    primal_bound::Float64,
    config::AlgorithmConfig,
)
    config.silent && return nothing
    m = num_constraints(fm)
    n = num_variables(fm)
    d = length(fm.disjunction_formulaters)
    @info "Cerberus: An (experimental) solver for disjunctive mixed-integer programming."
    @info "Optimizing a model with $m rows, $n columns, and $d disjunctive constraints."
    n_c = count(v -> v === nothing, fm.variable_kind)
    n_i = count(v -> v !== nothing, fm.variable_kind)
    n_b = count(v -> v isa ZO, fm.variable_kind)
    @assert n_i + n_c == n
    @info "Variables: $n_c continuous, $n_i integer ($n_b binary)."
    # TODO: Log problem size after formulation of disjunctions
    # TODO: Print table of coefficient statistics
    if primal_bound < Inf
        @info "Starting primal bound of $primal_bound"
    end
    @info "    Nodes    |    Current Node    |     Objective Bounds      |    Work"
    @info " Expl Unexpl |  Obj  Depth IntInf | Incumbent    BestBd   Gap | It/Node Time"
    return nothing
end

function _log_postamble(result::Result, config::AlgorithmConfig)
    config.silent && return nothing
    # TODO: Summarize cutting planes added (none right now...)
    @info Printf.@sprintf(
        "Explored %u nodes (%u simplex iterations) in %.2f seconds.",
        result.total_node_count,
        result.total_simplex_iters,
        result.total_elapsed_time_sec,
    )
    if result.termination_status == MOI.INFEASIBLE
        @info "Model is infeasible."
    elseif result.termination_status == MOI.DUAL_INFEASIBLE
        @info "Model is unbounded."
    else
        if result.termination_status == MOI.OPTIMAL
            @info "Optimal solution found."
        elseif result.primal_bound < Inf && all(!isnan, result.best_solution)
            @info "Feasible solution found."
        end
        @info Printf.@sprintf(
            "Best objective %10e, best bound %10e, gap %.4f%%.",
            result.primal_bound,
            result.dual_bound,
            _optimality_gap(result.primal_bound, result.dual_bound),
        )
    end
    return nothing
end

function _log_node_update(state::CurrentState, node_result::NodeResult)
    cost = node_result.cost
    gap = _optimality_gap(state.primal_bound, state.dual_bound)
    @info Printf.@sprintf(
        "%5u %5u   %8.5f %4u %4s %8s %8.5f %8s  %5.1f %5us",
        state.total_node_count,
        length(state.tree),
        cost,
        node_result.depth,
        # If infeasible, don't report int infeasibility as 0.
        if cost == Inf
            "    -"
        else
            Printf.@sprintf("%5u", node_result.int_infeas)
        end,
        if state.primal_bound == Inf
            "         -"
        else
            Printf.@sprintf("%8.5f", state.primal_bound)
        end,
        state.dual_bound,
        # If we don't have a primal bound, just don't report a gap.
        if isnan(gap)
            "      - "
        else
            (isinf(gap) ? "      ∞ " : Printf.@sprintf("%7.2f%%", gap))
        end,
        state.polling_state.period_simplex_iters /
        state.polling_state.period_node_count,
        floor(UInt, state.total_elapsed_time_sec),
    )
end

const EARLY_POLLING_CUTOFF = 10.0
const EARLY_POLLING_CADENCE = 0.25
const NORMAL_POLLING_CADENCE = 5.0

# TODO: Unit test
function _log_if_necessary(
    state::CurrentState,
    result::NodeResult,
    config::AlgorithmConfig,
)
    config.silent && return nothing
    elapsed_time_sec = state.total_elapsed_time_sec
    if elapsed_time_sec > state.polling_state.next_polling_target_time_sec
        update_dual_bound!(state)
        _log_node_update(state, result)
        if elapsed_time_sec <= EARLY_POLLING_CUTOFF
            state.polling_state.next_polling_target_time_sec +=
                EARLY_POLLING_CADENCE
        else
            state.polling_state.next_polling_target_time_sec +=
                NORMAL_POLLING_CADENCE
        end
        state.polling_state.period_node_count = 0
        state.polling_state.period_simplex_iters = 0
    end
    return nothing
end
