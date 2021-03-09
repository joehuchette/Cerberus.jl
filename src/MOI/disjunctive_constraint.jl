
function MOI.supports_constraint(
    ::Optimizer,
    ::Type{VAF},
    ::Type{DisjunctiveConstraints.DisjunctiveSet{Float64}},
)
    return true
end

function MOI.is_valid(
    opt::Optimizer,
    c::CI{VAF,DisjunctiveConstraints.DisjunctiveSet{Float64}},
)
    return 1 <= c.value <= num_disjunctive_constraints(opt.form)
end

function MOI.add_constraint(
    opt::Optimizer,
    _f::VAF,
    s::DisjunctiveConstraints.DisjunctiveSet{Float64},
)
    f = convert.(CSAF, MOIU.scalarize(_f))
    disj = Disjunction(f, s)
    # TODO: Make this configurable
    df = DisjunctiveFormulater(
        disj,
        DisjunctiveConstraints.NaiveBigM(
            DisjunctiveConstraints.IntervalArithmetic(),
        ),
    )
    attach_formulater!(opt.form, df)
    return CI{VAF,DisjunctiveConstraints.DisjunctiveSet{Float64}}(
        num_disjunctive_constraints(opt.form),
    )
end

function MOI.get(
    opt::Optimizer,
    ::MOI.NumberOfConstraints{
        VAF,
        DisjunctiveConstraints.DisjunctiveSet{Float64},
    },
)
    return num_disjunctive_constraints(opt.form)
end

function MOI.get(
    opt::Optimizer,
    ::MOI.ListOfConstraintIndices{
        VAF,
        DisjunctiveConstraints.DisjunctiveSet{Float64},
    },
)
    return [
        CI{VAF,DisjunctiveConstraints.DisjunctiveSet{Float64}}(i) for
        i in 1:num_disjunctive_constraints(opt.form)
    ]
end
