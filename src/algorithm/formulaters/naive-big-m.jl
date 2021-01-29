# NOTE: Since raw indices are cached here, these cannot be reused multiple
# times across models.
struct NaiveBigMFormulater{S<:DisjunctiveConstraints.AbstractActivityMethod} <:
       AbstractBigMFormulater
    disjunction::Disjunction
    activity_method::S

    function NaiveBigMFormulater{S}(
        disjunction::Disjunction,
        activity_method::S,
    ) where {S<:DisjunctiveConstraints.AbstractActivityMethod}
        if !isempty(disjunction.et_constrs)
            throw(
                ArgumentError(
                    "The naive big-M formulater does not currently accept equality constraints in any of the alternatives.",
                ),
            )
        end
        return new(disjunction, activity_method)
    end
end

struct NaiveBigMState <: AbstractFormulaterState
    sum_ci::CI{SAF,ET}
    lt_cis::Matrix{CI{SAF,LT}}
    gt_cis::Matrix{CI{SAF,GT}}
end

function new_variables_to_attach(formulater::NaiveBigMFormulater)
    return [ZO() for i in 1:length(formulater.disjunction)]
end

# TODO: Unit test
function _compute_disjunction_activity(
    form::DMIPFormulation,
    z_vis::Vector{VI},
    node::Node,
)
    proven_active = Bool[]
    proven_inactive = Bool[]
    for vi in z_vis
        l, u = _get_formulation_bounds(form, vi)
        if haskey(node.lb_diff, vi)
            l = max(l, node.lb_diff[vi])
        end
        if haskey(node.ub_diff, vi)
            u = min(u, node.ub_diff[vi])
        end
        push!(proven_active, l == u == 1)
        push!(not_inactive, l <= 0 & 1 <= u)
    end
    return proven_active, not_inactive
end

# TODO: Unit test
function _copy_with_new_variable_indices(f::VOV, new_vis::Vector{VI})
    return VOV([new_vis[i] for i in 1:length(f.variables)])
end

# TODO: Unit test
function _copy_with_new_variable_indices(f::VAF, new_vis::Vector{VI})
    terms = [
        VAT(
            term.output_index,
            SAT(term.coefficient, new_vis[term.variable_index.value]),
        ) for term in f.terms
    ]
    return VAF(terms, copy(f.constants))
end

# TODO: Unit test
function _mask_and_update_variable_indices(
    model_disj::Disjunction,
    new_vis::Vector{VI},
    mask::Vector{Bool},
)
    return Disjunction(
        _copy_with_new_indices(model_disj.f, new_vis),
        s[:, mask],
    )
end

# TODO: Unit test
function formulate!(
    state::CurrentState,
    formulater::NaiveBigMFormulater,
    form::DMIPFormulation,
    z_vis::Vector{VI},
    node::Node,
)
    # TODO: If proven_active is all falses, can bail out as infeasible. If
    # there is exactly one true, no need to write a disjunctive formulation.
    # The tricky thing in that second case is that we need to cache that info
    # somehow in the Basis, so that when/if we backtrack we can figure out
    # which constraints to use.
    proven_active, not_inactive =
        _compute_disjunction_activity(form, z_vis, node)
    disjunction = _mask_and_update_variable_indices(
        formulater.disjunction,
        state.variable_indices,
        not_inactive,
    )

    sum_ci, lt_cis, gt_cis = DisjunctiveConstraints.naive_big_m_formulations!(
        state.gurobi_model,
        DisjunctiveConstraints.NaiveBigM(formulater.activity_method),
        disjunction,
        z_vis,
    )

    return NaiveBigMState(sum_ci, lt_cis, gt_cis)
end
