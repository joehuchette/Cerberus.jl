const Disjunction = DisjunctiveConstraints.Disjunction
const DisjunctiveSet = DisjunctiveConstraints.DisjunctiveSet

abstract type AbstractBigMFormulater <: AbstractFormulater end

"""
    new_variables_to_attach(formulater::AbstractFormulater)::Vector{Int}

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

# TODO: Unit test
function _copy_with_new_variable_indices(f::VOV, new_vis::Vector{VI})
    return VOV([new_vis[vi.value] for vi in f.variables])
end

# TODO: Unit test
function _copy_with_new_variable_indices(f::VAF, new_vis::Vector{VI})
    terms = [
        VAT(
            term.output_index,
            SAT(term.scalar_term.coefficient, new_vis[term.scalar_term.variable_index.value]),
        ) for term in f.terms
    ]
    return VAF(terms, copy(f.constants))
end

# TODO: Unit test
function mask_and_update_variable_indices(
    model_disj::Disjunction,
    new_vis::Vector{VI},
    mask::Vector{Bool},
)
    return Disjunction(
        _copy_with_new_variable_indices(model_disj.f, new_vis),
        DisjunctiveConstraints.DisjunctiveSet(model_disj.s.lbs[:, mask], model_disj.s.ubs[:, mask]),
    )
end

function compute_disjunction_activity end
