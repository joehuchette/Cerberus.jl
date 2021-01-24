const _VI = MOI.VariableIndex
const _SV = MOI.SingleVariable
const _SAT = MOI.ScalarAffineTerm{Float64}
const _SAF = MOI.ScalarAffineFunction{Float64}
const _ET = MOI.EqualTo{Float64}
const _GT = MOI.GreaterThan{Float64}
const _LT = MOI.LessThan{Float64}
const _IN = MOI.Interval{Float64}
const _CI = MOI.ConstraintIndex
const _ZO = MOI.ZeroOne
const _GI = MOI.Integer

function _build_polyhedron()
    v = [_SV(_VI(i)) for i in 1:3]
    return Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(v[1] + 2.1 * v[2] + 3.0 * v[3], _ET(3.0)),
            Cerberus.AffineConstraint(-3.5 * v[1] + 1.2 * v[2], _LT(4.0)),
        ],
        [_IN(0.5, 1.0), _IN(-1.3, 2.3), _IN(0.0, 1.0)],
    )
end

function _build_dmip_formulation()
    v = [_SV(_VI(i)) for i in 1:3]
    return Cerberus.DMIPFormulation(
        _build_polyhedron(),
        Cerberus.AbstractFormulater[],
        [_ZO(), nothing, _ZO()],
        1.0 * v[1] - 1.0 * v[2],
    )
end

function _build_gi_polyhedron()
    v = [_SV(_VI(i)) for i in 1:3]
    return Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(
                1.3 * v[1] + 3.7 * v[2] + 2.4 * v[3],
                _LT(5.5),
            ),
        ],
        [_IN(0.0, 4.5), _IN(0.0, 1.0), _IN(0.0, 3.0)],
    )
end

function _build_gi_dmip_formulation()
    return Cerberus.DMIPFormulation(
        _build_gi_polyhedron(),
        Cerberus.AbstractFormulater[],
        [nothing, _ZO(), _GI()],
        convert(_SAF, 0.0),
    )
end

# Indices correspond to what Gurobi.jl, not Cerberus, uses
const DMIP_BASIS = Cerberus.Basis(
    [MOI.NONBASIC_AT_LOWER, MOI.BASIC, MOI.NONBASIC_AT_LOWER],
    [MOI.BASIC],
    MOI.BasisStatusCode[],
    [MOI.NONBASIC],
    MOI.BasisStatusCode[],
    MOI.BasisStatusCode[],
)

function _test_is_equal_to_dmip_basis(basis::Cerberus.Basis)
    @test basis.base_var_constrs == DMIP_BASIS.base_var_constrs
    @test basis.base_lt_constrs == DMIP_BASIS.base_lt_constrs
    @test basis.base_gt_constrs == DMIP_BASIS.base_gt_constrs
    @test basis.base_et_constrs == DMIP_BASIS.base_et_constrs
    @test basis.branch_lt_constrs == DMIP_BASIS.branch_lt_constrs
    @test basis.branch_gt_constrs == DMIP_BASIS.branch_gt_constrs
end
