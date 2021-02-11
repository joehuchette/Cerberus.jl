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
    return fill(
        ZO(),
        DisjunctiveConstraints.num_alternatives(formulater.disjunction.s),
    )
end

# TODO: Unit test
# NOTE: This will ignore any general constraints in `node`.
function compute_disjunction_activity(
    form::DMIPFormulation,
    z_vis::Vector{CVI},
    node::Node,
    ϵ_int::Float64,
)
    lbs = Dict{CVI,Float64}()
    ubs = Dict{CVI,Float64}()
    for cvi in z_vis
        @assert !haskey(lbs, cvi)
        @assert !haskey(ubs, cvi)
        l, u = get_bounds(form, cvi)
        lbs[cvi] = l
        ubs[cvi] = u
    end
    for lt_bound in node.lt_bounds
        ubs[lt_bound.cvi] = min(ubs[lt_bound.cvi], lt_bound.s.upper)
    end
    for gt_bound in node.gt_bounds
        lbs[gt_bound.cvi] = max(lbs[gt_bound.cvi], gt_bound.s.lower)
    end

    proven_active = Bool[]
    not_inactive = Bool[]
    for cvi in z_vis
        l = lbs[cvi]
        u = ubs[cvi]
        # Approximate version of: l == 1 == u
        push!(proven_active, (abs(l - 1) ≤ ϵ_int) & (abs(u - 1) ≤ ϵ_int))
        # Approximate version of: l <= 1 <= u
        push!(not_inactive, (l ≤ 1 + ϵ_int) & (1 <= u + ϵ_int))
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
    config::AlgorithmConfig,
)
    cvis = form.disjunction_formulaters[formulater]
    # TODO: If proven_active contains more than one true, can bail out as infeasible. If
    # there is exactly one true, no need to write a disjunctive formulation.
    # The tricky thing in that second case is that we need to cache that info
    # somehow in the Basis, so that when/if we backtrack we can figure out
    # which constraints to use.
    proven_active, not_inactive =
        compute_disjunction_activity(form, cvis, node, config.int_tol)
    _f = [instantiate(v, state) for v in formulater.disjunction.f]
    f = MOIU.vectorize(_f)
    masked_lbs = formulater.disjunction.s.lbs[:, not_inactive]
    masked_ubs = formulater.disjunction.s.ubs[:, not_inactive]
    s = DisjunctiveConstraints.DisjunctiveSet(masked_lbs, masked_ubs)

    disj_state = DisjunctiveConstraints.formulate!(
        state.gurobi_model,
        DisjunctiveConstraints.NaiveBigM(formulater.activity_method),
        DisjunctiveConstraints.Disjunction(f, s),
        [instantiate(cvi, state) for cvi in cvis[not_inactive]],
    )
    state.disjunction_state[formulater] = disj_state
    return nothing
end
