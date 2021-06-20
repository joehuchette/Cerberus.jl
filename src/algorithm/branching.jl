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

"""
Abstract type representing a possible way the algorithm could branch. Allows us
to understand the value in taking this particular branching choice without
instantiating all of the data structures necessary to actually represent it.
"""
abstract type AbstractBranchingCandidate end

"""
Represent a variable branching candidate in terms of: 1) the variable being
branched on, and 2) its fractional value at the LP solution.
"""
struct VariableBranchingCandidate <: AbstractBranchingCandidate
    index::CVI
    value::Float64
end

"""
    branching_candidates(form::DMIPFormulation, nr::NodeResult, config::AlgorithmConfig{B}) where {B <: AbstractBranchingRule}

Given the formulation, the result from the node LP solve, and the branching
rule (of type `B` as encoded in `config`), returns a vector of potential
branching candidates.

For example, if `B <: AbstractVariableBranchingRule`, there is a method which
will inspect the current LP solution and return branching candidates for each
integer variable taking a fractional value.
"""
function branching_candidates end

function branching_candidates(
    form::DMIPFormulation,
    parent_result::NodeResult,
    config::AlgorithmConfig{B},
)::Vector{VariableBranchingCandidate} where {B<:AbstractVariableBranchingRule}
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

"""
Abstract type representing a numeric scoring for a branching candidate.
"""
abstract type AbstractBranchingScore end

"""
Generic representation for scoring a variable branching candidate in terms of
a score for the down branch, a score for the up branch, and an aggregate
for the two.
"""
struct VariableBranchingScore <: AbstractBranchingScore
    down_branch_score::Float64
    up_branch_score::Float64
    aggregate_score::Float64
end

"""
    aggregate_score(::AbstractBranchingScore)::Float64

Represent a scoring for a branching candidate using a scalar numeric value.
Conventionally, this will be a value between 0 and 1.
"""
function aggregate_score end

aggregate_score(vbs::VariableBranchingScore) = vbs.aggregate_score

"""
    branch_on(parent_node::Node, candidate::AbstractBranchingCandidate, score::AbstractBranchingScore)::NTuple{Node}

Given a node, a selected branching candidate, and a score for that candidate,
apply that branching. The return value will be a tuple of `Node`s. These nodes
will be proved in increasing order of preference, i.e. the _last_ entry in the
return tuple will be the favorite.

Note:
* The memory in `parent_node` should remain untouched unaliased.
"""
function branch_on end

function branch_on(
    parent_node::Node,
    candidate::VariableBranchingCandidate,
    score::VariableBranchingScore,
)::Tuple{Node,Node}
    db = down_branch(parent_node, candidate.index, candidate.value)
    ub = up_branch(parent_node, candidate.index, candidate.value)
    if score.down_branch_score > score.up_branch_score
        return ub, db
    else
        return db, ub
    end
end

"""
    branching_score(state::CurrentState, bc::AbstractBranchingCandidate, nr::NodeResult, config::AlgorithmConfig)::AbstractBranchingScore

Scores a given branching candidate that could potentially be taken at the
current node.

Note:
* The two methods are added to hide the
"""
function branching_score end

function branching_score(
    ::CurrentState,
    bc::VariableBranchingCandidate,
    parent_result::NodeResult,
    config::AlgorithmConfig{MostInfeasible},
)
    xi = parent_result.x[index(bc.index)]
    xi_f = _approx_floor(xi, config.int_tol)
    xi_c = _approx_ceil(xi, config.int_tol)
    f⁺ = xi_c - xi
    f⁻ = xi - xi_f
    return VariableBranchingScore(f⁻, f⁺, min(f⁻, f⁺))
end

function branching_score(
    state::CurrentState,
    bc::VariableBranchingCandidate,
    parent_result::NodeResult,
    config::AlgorithmConfig{StrongBranching},
)
    sb_model = config.lp_solver_factory(state, config)
    MOI.copy_to(sb_model, state.gurobi_model)

    c = parent_result.cost
    cvi = bc.index
    xi = parent_result.x[index(cvi)]

    low_bound = _approx_floor(xi, config.int_tol)
    up_bound = _approx_ceil(xi, config.int_tol)
    ci = state.constraint_state.base_state.var_constrs[index(cvi)]

    c_up = _branch_cost(sb_model, GT(up_bound), ci)
    c_down = _branch_cost(sb_model, LT(low_bound), ci)

    μ = config.branching_rule.μ
    f⁻ = c_down - c
    f⁺ = c_up - c
    f = (1 - μ) * min(f⁺, f⁻) + μ * max(f⁺, f⁻)
    return VariableBranchingScore(f⁻, f⁺, f)
end

"""
    _branch_cost(model::Gurobi.Optimizer, constraint::Union{LT, GT}, ci::CI)

Computes the optimal objective cost of a branch.

The model is added with the new constraint, solved to optimal, and then
set back to the original.
"""
function _branch_cost(
    model::Gurobi.Optimizer,
    constraint::Union{LT, GT},
    ci::CI,
)
    interval = MOI.get(model, MOI.ConstraintSet(), ci)
    temp_interval = IN(
    constraint isa LT ? interval.lower : max(constraint.lower, interval.lower),
    constraint isa GT ? interval.upper : min(constraint.upper, interval.upper))

    MOI.set(model, MOI.ConstraintSet(), ci, temp_interval)
    MOI.optimize!(model)
    term_status = MOI.get(model, MOI.TerminationStatus())

    # assume that the case where a branch is unbounded will never happen
    cost = (if term_status == MOI.OPTIMAL
                MOI.get(model, MOI.ObjectiveValue())
            elseif term_status == MOI.INFEASIBLE || term_status == MOI.INFEASIBLE_OR_UNBOUNDED
                Inf
            else
                error("Unexpected termination status $term_status at node LP
                       when performing strong branching.")
            end
            )
    MOI.set(model, MOI.ConstraintSet(), ci, interval)
    return cost
end

"""
Given a current node and node LP result, branch. The return value will be a
tuple of `Node`s corresponding to the childen created by the branching.

This is a generic implementation which should support multiway branching and
general constraint branching. However, the "easy" case with binary variable
branching should be type stable and efficient.

Note:
* This method will error if branching is not valid. This is encoded via
`branching_candidates`: if no candidates are returned, then this function will
error.
"""
function branch(
    state::CurrentState,
    form::DMIPFormulation,
    parent_node::Node,
    parent_result::NodeResult,
    config::AlgorithmConfig,
)::NTuple
    # NOTE: The following calls dispatch on `config`. In the "simple" case
    # (i.e. variable branching), this should be type stable. In the more
    # complex case (general branching), it may not be.
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
