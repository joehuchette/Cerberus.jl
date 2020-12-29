function _log_preamble(fm::DMIPFormulation, primal_bound::Float64)
    m = num_constraints(fm.base_form.feasible_region)
    n = num_variables(fm)
    d = length(fm.disjunction_formulaters)
    @info "Cerberus: An (experimental) solver for disjunctive mixed-integer programming."
    @info "Optimizing a model with $m rows, $n columns, and $d disjunctive constraints."
    n_c = count(v -> v === nothing, fm.integrality)
    n_i = count(v -> v !== nothing, fm.integrality)
    n_b = count(v -> v == ZO(), fm.integrality)
    @assert n_i + n_c == n
    @info "Variables: $n_c continuous, $n_i integer ($n_b binary)."
    # TODO: Log problem size after formulation of disjunctions
    # TODO: Print table of coefficient statistics
    if primal_bound < Inf
        @info "Starting primal bound of $primal_bound"
    end
    @info "    Nodes    |    Current Node    |     Objective Bounds      |    Work"
    @info " Expl Unexpl |  Obj  Depth IntInf | Incumbent    BestBd   Gap | Iters Time"
    @info ""
end

function _log_node_update(state::CurrentState)
    gap = _optimality_gap(state.primal_bound, state.dual_bound)
    @info Printf.@sprintf(
        "%5u %5u   %8.2f %3u %5u  %8.2f %8.2f %8s  %5u %7.2f",
        state.total_node_count,
        length(state.tree),
        state.node_result.cost,
        state.node_result.depth,
        state.node_result.int_infeas,
        state.primal_bound,
        state.dual_bound,
        isnan(gap) ? "      - " : Printf.@sprintf("%7.2f%%", gap),
        state.node_result.simplex_iters,
        state.total_elapsed_time_sec,
    )
end
