abstract type BranchingRule end
struct MostInfeasible <: BranchingRule end
struct PseudocostBranching <: BranchingRule end

const DEFAULT_LP_SOLVER_FACTORY =
    (state, config) -> begin
        model = Gurobi.Optimizer(state.gurobi_env)
        MOI.set(model, MOI.Silent(), config.silent)
        model
    end
# TODO: Change to true after initial dev work
const DEFAULT_SILENT = false
const DEFAULT_BRANCHING_RULE = MostInfeasible()
const DEFAULT_NODE_LIMIT = 1_000_000
const DEFAULT_GAP_TOL = 1e-4
const DEFAULT_INTEGRALITY_TOL = 1e-5
const DEFAULT_WARM_START = true
const DEFAULT_HOT_START = false

# TODO: Use Base.@kwdef
mutable struct AlgorithmConfig
    lp_solver_factory::Function
    silent::Bool
    branching_rule::BranchingRule
    node_limit::Int
    gap_tol::Float64
    int_tol::Float64
    warm_start::Bool
    hot_start::Bool

    function AlgorithmConfig(;
        lp_solver_factory::Function = DEFAULT_LP_SOLVER_FACTORY,
        silent::Bool = DEFAULT_SILENT,
        branching_rule::BranchingRule = DEFAULT_BRANCHING_RULE,
        node_limit::Real = DEFAULT_NODE_LIMIT,
        gap_tol::Real = DEFAULT_GAP_TOL,
        int_tol::Real = DEFAULT_INTEGRALITY_TOL,
        warm_start::Bool = DEFAULT_WARM_START,
        hot_start::Bool = DEFAULT_HOT_START,
    )
        @assert node_limit >= 0
        @assert isinteger(node_limit)
        @assert gap_tol >= 0
        @assert int_tol >= 0
        return new(
            lp_solver_factory,
            silent,
            branching_rule,
            node_limit,
            gap_tol,
            int_tol,
            warm_start,
            hot_start,
        )
    end
end
