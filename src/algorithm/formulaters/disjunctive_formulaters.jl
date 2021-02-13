"""
    new_variables_to_attach(formulater::DisjunctiveFormulater)::Vector{Int}

Returns a vector of the kinds (from `_V_INT_SETS`) of the variables added
_every time_ that `formulater` is applied to a model. The contract is: these
variables will always be included in a model, regardless of which node it is
created at. Variable creation will be handled by `populate_base_model!`; it is
not the role of `formulater` to create them.

This function returns the raw column indices used to reference these variables
inside the `formulater`. The interpretation is: if the index `i` is in the
returned vector, then you may look up the corresponding variable index as
`state.variable_indices[i]`.

Note that the new variables need not all be integers; extended formulations can
register additional continuous variables (though this is not necessary--
formulaters can add additional continuous variables not registered with the
formulation in this manner, provided they handle basis getting/setting
appropriately). But any integer variables that you wish to branch on _must_ be
 registered in this manner.
"""
function new_variables_to_attach end

function compute_disjunction_activity end

function formulate!(
    state::CurrentState,
    form::DMIPFormulation,
    formulater::DisjunctiveFormulater,
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
        compute_disjunction_activity(form, formulater, node, config)
    _f = [instantiate(v, state) for v in formulater.disjunction.f]
    f = MOIU.vectorize(_f)
    masked_lbs = formulater.disjunction.s.lbs[:, not_inactive]
    masked_ubs = formulater.disjunction.s.ubs[:, not_inactive]
    s = DisjunctiveConstraints.DisjunctiveSet(masked_lbs, masked_ubs)

    disj_state = DisjunctiveConstraints.formulate!(
        state.gurobi_model,
        formulater.method,
        DisjunctiveConstraints.Disjunction(f, s),
        [instantiate(cvi, state) for cvi in cvis[not_inactive]],
    )
    state.disjunction_state[formulater] = disj_state
    return nothing
end
