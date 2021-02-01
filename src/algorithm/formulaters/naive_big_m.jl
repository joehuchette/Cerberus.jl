# NOTE: Since raw indices are cached here, these cannot be reused multiple
# times across models.
struct NaiveBigMFormulater{S<:DisjunctiveConstraints.AbstractActivityMethod} <:
       AbstractBigMFormulater
    disjunction::Disjunction
    activity_method::S
end

struct NaiveBigMState <: AbstractFormulaterState
    z_vis::Vector{VI}
    sum_ci::CI{SAF,ET}
    lt_cis::Matrix{Union{Nothing,CI{SAF,LT}}}
    gt_cis::Matrix{Union{Nothing,CI{SAF,GT}}}
end

function new_variables_to_attach(formulater::NaiveBigMFormulater)
    return [
        ZO() for
        i in 1:DisjunctiveConstraints.num_alternatives(formulater.disjunction.s)
    ]
end

# TODO: Unit test
# NOTE: This will ignore any general constraints in `node`.
function compute_disjunction_activity(
    form::DMIPFormulation,
    z_vis::Vector{Int},
    node::Node,
)
    proven_active = Bool[]
    not_inactive = Bool[]
    for idx in z_vis
        cvi = CVI(idx)
        l, u = get_bounds(form, cvi)
        if haskey(node.lb_diff, cvi)
            l = max(l, node.lb_diff[cvi])
        end
        if haskey(node.ub_diff, cvi)
            u = min(u, node.ub_diff[cvi])
        end
        push!(proven_active, l == u == 1)
        push!(not_inactive, l <= 1 <= u)
    end
    return proven_active, not_inactive
end

# TODO: Unit test
# TODO: The following can be abstracted and moved to disjunctive_formulaters.jl
function formulate!(
    state::CurrentState,
    form::DMIPFormulation,
    formulater::NaiveBigMFormulater,
    node::Node,
)
    z_vis = state.variable_indices[form.disjunction_formulaters[formulater]]
    # TODO: If proven_active is all falses, can bail out as infeasible. If
    # there is exactly one true, no need to write a disjunctive formulation.
    # The tricky thing in that second case is that we need to cache that info
    # somehow in the Basis, so that when/if we backtrack we can figure out
    # which constraints to use.
    proven_active, not_inactive =
        compute_disjunction_activity(form, z_vis, node)
    disjunction = mask_and_update_variable_indices(
        formulater.disjunction,
        state.variable_indices,
        not_inactive,
    )

    disj_state = DisjunctiveConstraints.formulate!(
        state.gurobi_model,
        DisjunctiveConstraints.NaiveBigM(formulater.activity_method),
        disjunction,
        z_vis,
    )
    state.disjunction_state[formulater] = disj_state
    return nothing
end
