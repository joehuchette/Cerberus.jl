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

function new_variables_to_attach(formulater::NaiveBigMFormulater)
    return [ZO() for i in 1:length(formulater.disjunction)]
end

function formulate!(
    state::CurrentState,
    formulater::NaiveBigMFormulater,
    z_vis::Vector{VI},
    node::Node,
)
    disjunction_state = BigMState(z_vis)
    model = state.gurobi_model
    num_alternatives = length(formulater.disjunction)

    ci = MOI.add_constraint(model, MOIU.sum(z_vis), ET(1.0))
    push!(disjunction_state.et_constrs, ci)
    for i in 1:num_alternatives
        alternative = formulator.disjunction[i]
        for lt_constr in alternative.lt_constrs
            f, s = lt_constr.f, lt_constr.s
            # TODO: Use Node info here to tighten value
            m_val = DisjunctiveConstraints.maximum_activity(
                model,
                f,
                formulater.activity_method,
            )
            ci = MOI.add_constraint(
                model,
                f + (s.upper - m_val) * z_vis[i],
                LT(s.upper),
            )
            push!(disjunction_state.lt_constrs, ci)
        end
        for gt_constr in alternative.gt_constrs
            f, s = gt_constr.f, gt_constr.s
            # TODO: Use Node info here to tighten value
            m_val = DisjunctiveConstraints.minimum_activity(
                model,
                f,
                formulater.activity_method,
            )
            ci = MOI.add_constraint(
                model,
                f + (s.lower - m_val) * z_vis[i],
                GT(s.lower),
            )
            push!(disjunction_state.gt_constrs, ci)
        end
        # TODO: Once equality constraints are "turned on", will need a loop
        # through them where we add one lt and one gt constraint.
    end
    return disjunction_state
end
