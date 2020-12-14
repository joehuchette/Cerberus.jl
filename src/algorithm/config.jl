const DEFAULT_NODE_LIMIT = 1_000
const DEFAULT_GAP_TOL = 1e-4

struct AlgorithmConfig
    node_limit::Int
    gap_tol::Float64
end
function AlgorithmConfig()
    return AlgorithmConfig(
        DEFAULT_NODE_LIMIT,
        DEFAULT_GAP_TOL,
    )
end
