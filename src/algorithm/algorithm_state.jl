mutable struct NodeResult
    cost::Float64
    x::Vector{Float64}
    simplex_iters::Int
    depth::Int
    int_infeas::Int
end

function NodeResult()
    return NodeResult(NaN, Float64[], 0, 0, 0)
end

mutable struct PollingState
    next_polling_target_time_sec::Float64
    period_node_count::Int
    period_simplex_iters::Int
end
PollingState() = PollingState(0.0, 0, 0)

mutable struct ConstraintState
    lt_constrs::Vector{CI{SAF,LT}}
    gt_constrs::Vector{CI{SAF,GT}}
    et_constrs::Vector{CI{SAF,ET}}
    var_constrs::Vector{CI{SV,IN}}
end
function ConstraintState(fm::DMIPFormulation)
    p = fm.base_form.feasible_region
    return ConstraintState(
        Vector{CI{SAF,LT}}(undef, num_constraints(p, LT)),
        Vector{CI{SAF,GT}}(undef, num_constraints(p, GT)),
        Vector{CI{SAF,ET}}(undef, num_constraints(p, ET)),
        Vector{CI{SV,IN}}(undef, ambient_dim(p)),
    )
end

struct Basis
    lt_constrs::Dict{CI{SAF,LT},MOI.BasisStatusCode}
    gt_constrs::Dict{CI{SAF,GT},MOI.BasisStatusCode}
    et_constrs::Dict{CI{SAF,ET},MOI.BasisStatusCode}
    var_constrs::Dict{CI{SV,IN},MOI.BasisStatusCode}
end
Basis() = Basis(Dict(), Dict(), Dict(), Dict())

# TODO: Unit test
function Base.copy(src::Basis)
    dest = Basis()
    for (k, v) in src.lt_constrs
        dest.lt_constrs[k] = v
    end
    for (k, v) in src.gt_constrs
        dest.gt_constrs[k] = v
    end
    for (k, v) in src.et_constrs
        dest.et_constrs[k] = v
    end
    for (k, v) in src.var_constrs
        dest.var_constrs[k] = v
    end
    return dest
end

mutable struct CurrentState
    gurobi_env::Gurobi.Env
    gurobi_model::Gurobi.Optimizer
    model_invalidated::Bool
    tree::Tree
    warm_starts::Dict{Node,Basis}
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Vector{Float64}
    starting_time::Float64
    total_elapsed_time_sec::Float64
    total_node_count::Int
    total_simplex_iters::Int
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
        # Don't set gurobi_model, just mark it as invalidated to force build.
        state.model_invalidated = true
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
