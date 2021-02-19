function apply_branching!(node::Node, bu::BoundUpdate{LT})
    node.depth += 1
    push!(node.lt_bounds, bu)
    return nothing
end

function apply_branching!(node::Node, bu::BoundUpdate{GT})
    node.depth += 1
    push!(node.gt_bounds, bu)
    return nothing
end

function apply_branching!(node::Node, ac::AffineConstraint{LT})
    node.depth += 1
    # NOTE: Can potentially modify bd in-place; would need to note this in the
    # contract, though.
    f = CSAF(ac.f.coeffs, ac.f.indices, 0.0)
    s = LT(ac.s.upper - ac.f.constant)
    push!(node.lt_general_constrs, AffineConstraint(f, s))
    return nothing
end

function apply_branching!(node::Node, ac::AffineConstraint{GT})
    node.depth += 1
    # NOTE: Can potentially modify bd in-place; would need to note this in the
    # contract, though.
    f = CSAF(ac.f.coeffs, ac.f.indices, 0.0)
    s = GT(ac.s.lower - ac.f.constant)
    push!(node.gt_general_constrs, AffineConstraint(f, s))
    return nothing
end

function down_branch(node::Node, branch_cvi::CVI, val::Float64)
    return _branch(node, branch_cvi, LT(floor(Int, val)))
end

function up_branch(node::Node, branch_cvi::CVI, val::Float64)
    return _branch(node, branch_cvi, GT(ceil(Int, val)))
end

function _branch(node::Node, branch_cvi::CVI, set::S) where {S<:Union{LT,GT}}
    # TODO: Can likely reuse this memory instead of copying
    new_node = copy(node)
    apply_branching!(new_node, BoundUpdate(branch_cvi, set))
    return new_node
end

abstract type AbstractBranchingCandidate end
struct VariableBranchingCandidate <: AbstractBranchingCandidate
    cvi::CVI
    x_val::Float64
end

# Fallback that works for variable branching. Add new methods for branching on
# general constraints.
function branching_candidates(
    form::DMIPFormulation,
    parent_result::NodeResult,
    config::AlgorithmConfig,
)
    return branching_candidates(
        config.branching_rule,
        form,
        parent_result,
        config,
    )
end

function branching_candidates(
    br::AbstractVariableBranchingRule,
    form::DMIPFormulation,
    parent_result::NodeResult,
    config::AlgorithmConfig,
)::Vector{VariableBranchingCandidate}
    @assert config.branching_rule === br
    candidates = VariableBranchingCandidate[]
    for cvi in all_variables(form)
        var_set = get_variable_kind(form, cvi)
        if typeof(var_set) <: Union{ZO,GI}
            xi = parent_result.x[index(cvi)]
            xi_f = _approx_floor(xi, config.int_tol)
            xi_c = _approx_ceil(xi, config.int_tol)
            frac_val = min(xi - xi_f, xi_c - xi)
            if frac_val > config.int_tol
                # Otherwise, we're integral up to tolerance.
                push!(candidates, VariableBranchingCandidate(cvi, xi))
            end
        end
    end
    return candidates
end

abstract type AbstractBranchingScore end
struct VariableBranchingScore <: AbstractBranchingScore
    down_branch_score::Float64
    up_branch_score::Float64
    aggregate_score::Float64
end
aggregate_score(vbs::VariableBranchingScore) = vbs.aggregate_score

# Function returns nodes created by branching, in increasing preference order.
function branch_on(
    parent_node::Node,
    candidate::VariableBranchingCandidate,
    score::VariableBranchingScore,
)::Tuple{Node,Node}
    # How do we decide which to prioritize?
    db = down_branch(parent_node, candidate.cvi, candidate.x_val)
    ub = up_branch(parent_node, candidate.cvi, candidate.x_val)
    if score.down_branch_score > score.up_branch_score
        return ub, db
    else
        return db, ub
    end
end

function branching_score(
    state::CurrentState,
    bc::VariableBranchingCandidate,
    parent_result::NodeResult,
    config::AlgorithmConfig,
)
    return branching_score(
        config.branching_rule,
        state,
        bc,
        parent_result,
        config,
    )
end

function branching_score(
    ::MostInfeasible,
    ::CurrentState,
    bc::VariableBranchingCandidate,
    parent_result::NodeResult,
    config::AlgorithmConfig,
)
    xi = parent_result.x[index(bc.cvi)]
    xi_f = _approx_floor(xi, config.int_tol)
    xi_c = _approx_ceil(xi, config.int_tol)
    f⁺ = xi_c - xi
    f⁻ = xi - xi_f
    return VariableBranchingScore(f⁻, f⁺, min(f⁻, f⁺))
end

function branch(
    state::CurrentState,
    form::DMIPFormulation,
    parent_node::Node,
    parent_result::NodeResult,
    config::AlgorithmConfig,
)
    # NOTE: The following calls dispatch on config.branching_rule, behind a
    # function barrier. In the "simple" case (i.e. variable branching), this
    # should be type stable. In the more complex case (general branching), it
    # will not be.
    candidates = branching_candidates(form, parent_result, config)
    if isempty(candidates)
        error("No branching candidates--are you sure you want to be branching?")
    end
    scores = Dict(
        candidate =>
            branching_score(state, candidate, parent_result, config) for
        candidate in candidates
    )
    # TODO: Can make all of this more efficient, if bottleneck.
    agg_scores = Dict(
        candidate => aggregate_score(scores[candidate]) for
        candidate in candidates
    )
    best_agg_score, best_candidate = findmax(agg_scores)
    return branch_on(parent_node, best_candidate, scores[best_candidate])
end

struct DummyBranchingRule <: Cerberus.AbstractBranchingRule end
struct DummyBranchingCandidate <: Cerberus.AbstractBranchingCandidate
    cvi::CVI
end
struct DummyBranchingScore <: Cerberus.AbstractBranchingScore
    val::Any
end
function Cerberus.branching_candidates(
    ::DummyBranchingRule,
    ::Cerberus.DMIPFormulation,
    ::Cerberus.NodeResult,
    config::Cerberus.AlgorithmConfig,
)
    @assert config.branching_rule === DummyBranchingRule()
    return [DummyBranchingCandidate(CVI(1)), DummyBranchingCandidate(CVI(3))]
end
function Cerberus.branching_score(
    ::Cerberus.CurrentState,
    dbc::DummyBranchingCandidate,
    ::Cerberus.NodeResult,
    config::Cerberus.AlgorithmConfig,
)
    @assert config.branching_rule === DummyBranchingRule()
    return DummyBranchingScore(Cerberus.index(dbc.cvi))
end
Cerberus.aggregate_score(::DummyBranchingScore) = 42.0
function Cerberus.branch_on(
    node::Cerberus.Node,
    ::DummyBranchingCandidate,
    ::DummyBranchingScore,
)
    return (
        Cerberus.Node(
            vcat(node.lt_bounds, Cerberus.BoundUpdate(CVI(3), LT(0.0))),
            vcat(node.gt_bounds, Cerberus.BoundUpdate(CVI(3), GT(0.0))),
            node.depth + 1,
        ),
        Cerberus.Node(
            vcat(node.lt_bounds, Cerberus.BoundUpdate(CVI(3), LT(1.0))),
            vcat(node.gt_bounds, Cerberus.BoundUpdate(CVI(3), GT(1.0))),
            node.depth + 1,
        ),
        Cerberus.Node(
            vcat(node.lt_bounds, Cerberus.BoundUpdate(CVI(3), LT(2.0))),
            vcat(node.gt_bounds, Cerberus.BoundUpdate(CVI(3), GT(2.0))),
            node.depth + 1,
        ),
    )
end
