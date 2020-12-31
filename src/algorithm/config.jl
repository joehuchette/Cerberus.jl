abstract type BranchingRule end
struct MostInfeasible <: BranchingRule end
struct PseudocostBranching <: BranchingRule end

const DEFAULT_LP_SOLVER_FACTORY =
    (state, config) -> begin
        model = Gurobi.Optimizer(state.gurobi_env)
        MOI.set(model, MOI.Silent(), config.silent)
        model
    end
const DEFAULT_SILENT = true
const DEFAULT_BRANCHING_RULE = MostInfeasible()
const DEFAULT_NODE_LIMIT = 1_000_000
const DEFAULT_GAP_TOL = 1e-4
const DEFAULT_INTEGRALITY_TOL = 1e-5
const DEFAULT_WARM_START = true
const DEFAULT_HOT_START = false
const DEFAULT_LOG_OUTPUT = true

Base.@kwdef mutable struct AlgorithmConfig
    lp_solver_factory::Function = DEFAULT_LP_SOLVER_FACTORY
    silent::Bool = DEFAULT_SILENT
    branching_rule::BranchingRule = DEFAULT_BRANCHING_RULE
    node_limit::Int = DEFAULT_NODE_LIMIT
    gap_tol::Float64 = DEFAULT_GAP_TOL
    int_tol::Float64 = DEFAULT_INTEGRALITY_TOL
    warm_start::Bool = DEFAULT_WARM_START
    hot_start::Bool = DEFAULT_HOT_START
    log_output::Bool = DEFAULT_LOG_OUTPUT
end
