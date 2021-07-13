"""
    new_variables_to_attach(formulater::DisjunctiveFormulater)::Vector

Returns a vector of the kinds (from `_V_INT_SETS`) of the variables added
_every time_ that `formulater` is applied to a model. The contract is: these
variables will always be included in a model, regardless of which node it is
created at. Variable creation will be handled by `populate_lp_model!`; it is
not the role of `formulater` to create them.

This function returns the CVIs used to reference these variables in the model.

Note that the new variables need not all be integer; extended formulations can
register additional continuous variables (though this is not necessary--
formulaters can add additional continuous variables not registered with the
formulation in this manner, provided they handle basis getting/setting
appropriately). But any integer variables that you wish to branch on _must_ be
 registered in this manner.
"""
function new_variables_to_attach end

"""
    compute_disjunction_activity(
        form::DMIPFormulation,
        formulater::DisjunctiveFormulater{DisjunctiveConstraints.NaiveBigM},
        node::Node,
        config::AlgorithmConfig,
    )::Vector{Bool}

Computes the activity of a disjunctive constraint: That is, which alternatives
are still feasible for the current `node`.

Returns a vector `activity` of Bools. The entry `activity[i]` is `true` if the
`i`-th disjunction in `formulater.disjunction` is feasible, and false
otherwise.

Notes:
* If `activity` is all falses, the caller can infer that the entire problem is
    infeasible.
* Here, an alternative being "feasible" means that the associated values for
    the integer variables are feasible. Therefore, an alternative may be
    "infeasible" and yet still contained in the feasible region for the problem
    (if, for example, the alternative is completely contained in another).
"""
function compute_disjunction_activity end

"""
    delete_all_constraints!(model::Gurobi.Optimizer, disjunction_state)

Delete all constraints in `model` that were added to formulate a given
disjunctive constraint.
"""
function delete_all_constraints! end

function formulate!(
    state::CurrentState,
    form::DMIPFormulation,
    formulater::DisjunctiveFormulater,
    node::Node,
    node_result::NodeResult,
    config::AlgorithmConfig,
)
    cvis = form.disjunction_formulaters[formulater]
    # TODO: If activity has exactly one true, can model that alternative
    # directly. If activity is all falses, the problem is infeasible, and we
    # can "short circuit" and not worry about formulating or solving.
    activity = compute_disjunction_activity(form, formulater, node, config)
    _f = [instantiate(v, state) for v in formulater.disjunction.f]
    f = MOIU.vectorize(_f)
    # NOTE: Could be a bit more clever here, by dropping alternatives which are
    # proven not to be active. However, this may require us to slice into
    # `cvis` below in the call to `DisjunctiveConstraints.formulate!`.
    # TODO: Do what's described above.
    masked_lbs = copy(formulater.disjunction.s.lbs)
    masked_ubs = copy(formulater.disjunction.s.ubs)
    masked_lbs[:, (!).(activity)] .= -Inf
    masked_ubs[:, (!).(activity)] .= Inf
    s = DisjunctiveConstraints.DisjunctiveSet(masked_lbs, masked_ubs)

    disj_state = DisjunctiveConstraints.formulate!(
        state.gurobi_model,
        formulater.method,
        DisjunctiveConstraints.Disjunction(f, s),
        [instantiate(cvi, state) for cvi in cvis],
    )
    state.disjunction_state[formulater] = disj_state
    if disj_state.proven_infeasible
        node_result.status = INFEASIBLE_LP
        node_result.cost = Inf
    end
    return nothing
end
