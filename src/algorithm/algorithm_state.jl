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

mutable struct BaseConstraintState
    var_constrs::Vector{CI{SV,IN}}
    lt_constrs::Vector{CI{SAF,LT}}
    gt_constrs::Vector{CI{SAF,GT}}
    et_constrs::Vector{CI{SAF,ET}}
end
BaseConstraintState() = BaseConstraintState([], [], [], [])

function Base.empty!(cs::BaseConstraintState)
    empty!(cs.var_constrs)
    empty!(cs.lt_constrs)
    empty!(cs.gt_constrs)
    empty!(cs.et_constrs)
    return nothing
end

mutable struct BranchConstraintState
    num_lt_branches::Int
    num_gt_branches::Int
    lt_general_constrs::Vector{CI{SAF,LT}}
    gt_general_constrs::Vector{CI{SAF,GT}}
end
BranchConstraintState() = BranchConstraintState(0, 0, [], [])

function Base.empty!(cs::BranchConstraintState)
    cs.num_lt_branches = 0
    cs.num_gt_branches = 0
    empty!(cs.lt_general_constrs)
    empty!(cs.gt_general_constrs)
    return nothing
end

mutable struct ConstraintState
    base_state::BaseConstraintState
    branch_state::BranchConstraintState
end
function ConstraintState()
    return ConstraintState(BaseConstraintState(), BranchConstraintState())
end

function Base.empty!(cs::ConstraintState)
    empty!(cs.base_state)
    empty!(cs.branch_state)
    return nothing
end

mutable struct CurrentState
    gurobi_env::Gurobi.Env
    gurobi_model::Gurobi.Optimizer
    rebuild_model::Bool
    tree::Tree
    backtracking::Bool
    # TODO: Hashing nodes might be more expensive than we'd like. Instead, just
    # attach an ID to each node and use Ints as keys.
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
    _variable_indices::Vector{VI}
    constraint_state::ConstraintState
    disjunction_state::Dict{DisjunctiveFormulater,Any}
    polling_state::PollingState

    function CurrentState(form::DMIPFormulation; primal_bound::Real = Inf)
        nvars = num_variables(form)
        state = new()
        state.gurobi_env = Gurobi.Env()
        state.backtracking = false
        # gurobi_model is left undefined; build it before accessing.
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
        state._variable_indices = VI[]
        state.constraint_state = ConstraintState()
        state.disjunction_state = Dict()
        state.polling_state = PollingState()
        return state
    end
end

function reset_formulation_state!(state::CurrentState)
    empty!(state._variable_indices)
    empty!(state.constraint_state)
    empty!(state.disjunction_state)
    return nothing
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

# TODO: Unit test
function instantiate(cvi::CVI, state::CurrentState)
    return state._variable_indices[index(cvi)]
end

# TODO: Unit test
function instantiate(csaf::CSAF, state::CurrentState)
    return SAF(
        [
            SAT(coeff, instantiate(cvi, state)) for
            (coeff, cvi) in zip(csaf.coeffs, csaf.indices)
        ],
        csaf.constant,
    )
end

function attach_index!(state::CurrentState, vi::VI)
    push!(state._variable_indices, vi)
    return CVI(length(state._variable_indices))
end

get_index(state::CurrentState, cvi::CVI) = state._variable_indices[index(cvi)]
