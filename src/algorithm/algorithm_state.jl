struct Basis
    base_var_constrs::Vector{MOI.BasisStatusCode}
    base_lt_constrs::Vector{MOI.BasisStatusCode}
    base_gt_constrs::Vector{MOI.BasisStatusCode}
    base_et_constrs::Vector{MOI.BasisStatusCode}
    branch_lt_constrs::Vector{MOI.BasisStatusCode}
    branch_gt_constrs::Vector{MOI.BasisStatusCode}
end
Basis() = Basis([], [], [], [], [], [])

function Base.copy(src::Basis)
    return Basis(
        copy(src.base_var_constrs),
        copy(src.base_lt_constrs),
        copy(src.base_gt_constrs),
        copy(src.base_et_constrs),
        copy(src.branch_lt_constrs),
        copy(src.branch_gt_constrs),
    )
end

mutable struct PollingState
    next_polling_target_time_sec::Float64
    period_node_count::Int
    period_simplex_iters::Int
end
PollingState() = PollingState(0.0, 0, 0)

"""

"""
mutable struct ConstraintState
    base_var_constrs::Vector{CI{SV,IN}}
    base_lt_constrs::Vector{CI{SAF,LT}}
    base_gt_constrs::Vector{CI{SAF,GT}}
    base_et_constrs::Vector{CI{SAF,ET}}
    branch_lt_constrs::Vector{CI{SAF,LT}}
    branch_gt_constrs::Vector{CI{SAF,GT}}
end
function ConstraintState(fm::DMIPFormulation)
    p = fm.feasible_region
    return ConstraintState(
        Vector{CI{SV,IN}}[],
        Vector{CI{SAF,LT}}[],
        Vector{CI{SAF,GT}}[],
        Vector{CI{SAF,ET}}[],
        Vector{CI{SAF,LT}}[],
        Vector{CI{SAF,GT}}[],
    )
end

function Base.empty!(cs::ConstraintState)
    empty!(cs.base_var_constrs)
    empty!(cs.base_lt_constrs)
    empty!(cs.base_gt_constrs)
    empty!(cs.base_et_constrs)
    empty!(cs.branch_lt_constrs)
    empty!(cs.branch_gt_constrs)
    return nothing
end

mutable struct CurrentState
    gurobi_env::Gurobi.Env
    gurobi_model::Gurobi.Optimizer
    rebuild_model::Bool
    tree::Tree
    backtracking::Bool
    warm_starts::Dict{Node,Basis}
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Vector{Float64}
    starting_time::Float64
    total_elapsed_time_sec::Float64
    total_node_count::Int
    total_simplex_iters::Int
    total_model_builds::Int
    total_warm_starts::Int
    constraint_state::ConstraintState
    polling_state::PollingState

    function CurrentState(
        fm::DMIPFormulation,
        config::AlgorithmConfig;
        primal_bound::Real = Inf,
    )
        nvars = num_variables(fm)
        state = new()
        state.gurobi_env = Gurobi.Env()
        state.backtracking = false
        # Don't set gurobi_model, just mark it as invalidated to force build.
        state.rebuild_model = true
        state.tree = Tree()
        push_node!(state.tree, Node())
        state.warm_starts = Dict{Node,Basis}()
        state.primal_bound = primal_bound
        state.dual_bound = -Inf
        state.best_solution = fill(NaN, nvars)
        state.starting_time = time()
        state.total_elapsed_time_sec = 0.0
        state.total_node_count = 0
        state.total_simplex_iters = 0
        state.total_model_builds = 0
        state.total_warm_starts = 0
        state.constraint_state = ConstraintState(fm)
        state.polling_state = PollingState()
        return state
    end
end

function update_dual_bound!(state::CurrentState)
    if isempty(state.tree)
        # Tree is exhausted, so have proven optimality of best found solution.
        state.dual_bound = state.primal_bound
    else
        state.dual_bound =
            minimum(node.dual_bound for node in state.tree.open_nodes)
    end
    return nothing
end
