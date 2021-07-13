abstract type AbstractBranchingRule end
abstract type AbstractVariableBranchingRule <: AbstractBranchingRule end
struct MostInfeasible <: AbstractVariableBranchingRule end
struct PseudocostBranching <: AbstractVariableBranchingRule end
mutable struct StrongBranching <: AbstractVariableBranchingRule
    μ::Real
    StrongBranching(; μ::Real = 1 / 6) = new(μ)
end

@enum WarmStartStrategy NO_WARM_STARTS WARM_START_WHEN_BACKTRACKING WARM_START_WHENEVER_POSSIBLE
@enum ModelReuseStrategy NO_MODEL_REUSE REUSE_MODEL_ON_DIVES USE_SINGLE_MODEL
@enum FormulationTighteningStrategy STATIC_FORMULATION TIGHTEN_WHEN_REBUILDING TIGHTEN_AT_EACH_NODE

# NOTE: This is not a true configurable parameter; it should really only be
# changed for debugging.
const _SILENT_LP_SOLVER = true

function _default_lp_solver_factory(state, config)
    model = Gurobi.Optimizer(state.gurobi_env)
    # TODO: Rather than have factory as a configurable parameter, can probably
    # just get by with making `silence_lp_solver::Bool` a parameter.
    MOI.set(model, MOI.Silent(), _SILENT_LP_SOLVER)
    MOI.set(model, MOI.RawParameter("Method"), 1)
    MOI.set(model, MOI.RawParameter("Presolve"), 0)
    # TODO: Rather than set this parameter, we could instead handle the
    # INF_OR_UNBD case directly. However, this might require resolving
    # some node LPs, which is a bit tricky to do in the current design.
    MOI.set(model, MOI.RawParameter("DualReductions"), 0)
    MOI.set(model, MOI.RawParameter("InfUnbdInfo"), 1)
    return model
end
const DEFAULT_LP_SOLVER_FACTORY = _default_lp_solver_factory
const DEFAULT_SILENT = false
const DEFAULT_BRANCHING_RULE = MostInfeasible()
const DEFAULT_TIME_LIMIT_SEC = Inf
const DEFAULT_NODE_LIMIT = 10_000_000
const DEFAULT_GAP_TOL = 1e-4
const DEFAULT_INTEGRALITY_TOL = 1e-5
const DEFAULT_WARM_START_STRATEGY = WARM_START_WHEN_BACKTRACKING
const DEFAULT_MODEL_REUSE_STRATEGY = REUSE_MODEL_ON_DIVES
# TODO: Change this default to TIGHTEN_WHENEVER_POSSIBLE
const DEFAULT_FORMULATION_TIGHTENING_STRATEGY = TIGHTEN_WHEN_REBUILDING
const DEFAULT_ACTIVITY_METHOD = DisjunctiveConstraints.IntervalArithmetic()

Base.@kwdef mutable struct AlgorithmConfig{B<:AbstractBranchingRule}
    lp_solver_factory::Function = DEFAULT_LP_SOLVER_FACTORY
    silent::Bool = DEFAULT_SILENT
    branching_rule::B = DEFAULT_BRANCHING_RULE
    time_limit_sec::Float64 = DEFAULT_TIME_LIMIT_SEC
    node_limit::Int = DEFAULT_NODE_LIMIT
    gap_tol::Float64 = DEFAULT_GAP_TOL
    int_tol::Float64 = DEFAULT_INTEGRALITY_TOL
    warm_start_strategy::WarmStartStrategy = DEFAULT_WARM_START_STRATEGY
    model_reuse_strategy::ModelReuseStrategy = DEFAULT_MODEL_REUSE_STRATEGY
    formulation_tightening_strategy::FormulationTighteningStrategy =
        DEFAULT_FORMULATION_TIGHTENING_STRATEGY
    # TODO: Unit test this parameter
    activity_method::DisjunctiveConstraints.AbstractActivityMethod =
        DEFAULT_ACTIVITY_METHOD
end
