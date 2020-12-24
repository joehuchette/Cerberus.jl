# Follows Gurobi convention
function _optimality_gap(primal::Float64, dual::Float64)
    primal == dual == 0 && return 0.0
    primal == 0 && return Inf
    return abs(primal - dual) / abs(primal)
end
