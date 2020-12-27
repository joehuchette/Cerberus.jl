function _approx_ceil(val::Float64, ϵ::Float64)::Float64
    if (val - floor(val)) < ϵ
        return floor(val)
    end
    return ceil(val)
end

function _approx_floor(val::Float64, ϵ::Float64)::Float64
    if (ceil(val) - val) < ϵ
        return ceil(val)
    end
    return floor(val)
end

# Follows Gurobi convention
function _optimality_gap(primal::Float64, dual::Float64)
    primal == dual == 0 && return 0.0
    primal == 0 && return Inf
    return abs(primal - dual) / abs(primal)
end
