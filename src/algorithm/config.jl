const DEFAULT_NODE_LIMIT = 1_000
const DEFAULT_GAP_TOL = 1e-4

mutable struct AlgorithmConfig
    node_limit::Int
    gap_tol::Float64

    function AlgorithmConfig(node_limit::Real, gap_tol::Real)
        @assert node_limit >= 0
        @assert isinteger(node_limit)
        @assert gap_tol >= 0
        return new(node_limit, gap_tol)
    end
end
function AlgorithmConfig()
    return AlgorithmConfig(
        DEFAULT_NODE_LIMIT,
        DEFAULT_GAP_TOL,
    )
end
