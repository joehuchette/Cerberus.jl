_VI = MOI.VariableIndex
_SV = MOI.SingleVariable

_CI(i::Int) = MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.GreaterThan{Float64}}

function _build_polyhedron()
    v = [MOI.SingleVariable(MOI.VariableIndex(i)) for i in 1:3]
    return Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(
                v[1] + 2.1 * v[2] + 3.0 * v[3],
                MOI.EqualTo(3.0)
            ),
            Cerberus.AffineConstraint(
                -3.5 * v[1] + 1.2 * v[2],
                MOI.LessThan(4.0)
            ),
        ],
        [
            MOI.Interval(0.5, 1.0),
            MOI.Interval(-1.3, 2.3),
            MOI.Interval(0.0, 1.0),
        ]
    )
end

function _build_relaxation()
    poly = _build_polyhedron()
    v = [MOI.SingleVariable(MOI.VariableIndex(i)) for i in 1:3]
    return Cerberus.LPRelaxation(
        _build_polyhedron(),
        1.0 * v[1] - 1.0 * v[2],
    )
end

function _build_dmip_formulation()
    return Cerberus.DMIPFormulation(
        _build_relaxation(),
        Cerberus.AbstractFormulater[],
        [
            MOI.VariableIndex(1),
            MOI.VariableIndex(3),
        ]
    )
end
