# TODO: Unit test getters/setters
# NOTE: The ownership model of _basis and _model are a bit complicated. They
# will be potentially copied to a ParentInfo object, which will then take
# ownership of the data. This should be formalized and explicitly stated in the
# documentation.
mutable struct IncrementalData
    _basis::Union{Nothing,Basis}
    _model::Union{Nothing,Gurobi.Optimizer}
    spec::Incrementalism

    function IncrementalData(spec::Incrementalism)
        if spec == NO_INCREMENTALISM
            return new(nothing, nothing, spec)
        elseif spec == WARM_START
            return new(Basis(), nothing, spec)
        else
            @assert spec == HOT_START
            return new(Basis(), nothing, spec)
        end
    end
end

function reset!(data::IncrementalData)
    if data.spec == NO_INCREMENTALISM
        # Do nothing
    else
        @assert data.spec in (WARM_START, HOT_START)
        basis_sz = length(data._basis)
        empty!(data._basis)
        sizehint!(data._basis, basis_sz)
        data._model = nothing
    end
    return nothing
end

mutable struct NodeResult
    cost::Float64
    x::Vector{Float64}
    simplex_iters::Int
    depth::Int
    int_infeas::Int
    incremental_data::IncrementalData
end

function NodeResult(nvars::Int, config::AlgorithmConfig)
    return NodeResult(
        NaN,
        fill(NaN, nvars),
        0,
        0,
        0,
        IncrementalData(config.incrementalism),
    )
end

function get_basis(result::NodeResult)
    data = result.incremental_data
    if !(data.spec in (WARM_START, HOT_START))
        throw(ErrorException("You are not allowed to access the basis."))
    end
    return data._basis
end

function get_model(result::NodeResult)
    data = result.incremental_data
    if data.spec != HOT_START
        throw(ErrorException("You are not allowed to access the model."))
    end
    return data._model
end

function set_model!(result::NodeResult, model::Gurobi.Optimizer)
    data = result.incremental_data
    if data.spec != HOT_START
        throw(ErrorException("You are not allowed to access the model."))
    end
    data._model = model
    return nothing
end

function reset!(result::NodeResult)
    result.cost = NaN
    # Save sizes of x and basis; keys should not change throughout tree anyway
    fill!(result.x, NaN)
    result.simplex_iters = 0
    result.depth = 0
    result.int_infeas = 0
    reset!(result.incremental_data)
    return nothing
end

mutable struct PollingState
    next_polling_target_time_sec::Float64
    period_node_count::Int
    period_simplex_iters::Int
end
PollingState() = PollingState(0.0, 0, 0)

mutable struct CurrentState
    gurobi_env::Gurobi.Env
    tree::Tree
    node_result::NodeResult
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Vector{Float64}
    starting_time::Float64
    total_elapsed_time_sec::Float64
    total_node_count::Int
    total_simplex_iters::Int
    polling_state::PollingState

    function CurrentState(
        nvars::Int,
        config::AlgorithmConfig;
        primal_bound::Real = Inf,
    )
        state = new(
            Gurobi.Env(),
            Tree(),
            NodeResult(nvars, config),
            primal_bound,
            -Inf,
            fill(NaN, nvars),
            time(),
            0.0,
            0,
            0,
            PollingState(),
        )
        push_node!(state.tree, Node())
        return state
    end
end

function update_dual_bound!(state::CurrentState)
    if isempty(state.tree)
        # Tree is exhausted, so have proven optimality of best found solution.
        state.dual_bound = state.primal_bound
    else
        state.dual_bound = minimum(
            node.parent_info.dual_bound for node in state.tree.open_nodes
        )
    end
    return nothing
end
