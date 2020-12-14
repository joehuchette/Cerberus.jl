# Follows Gurobi convention
function _optimality_gap(state::CurrentState)
    primal = state.primal_bound
    dual = state.dual_bound
    primal == dual == 0 && return 0.0
    primal == 0 && return Inf
    return abs(primal - dual) / abs(primal)
end
