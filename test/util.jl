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

const _CVI = Cerberus.VariableIndex
const _CSAF = Cerberus.ScalarAffineFunction

function _build_polyhedron()
    return Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(
                _CSAF([1.0, 2.1, 3.0], [_CVI(1), _CVI(2), _CVI(3)], 0.0),
                _ET(3.0),
            ),
            Cerberus.AffineConstraint(
                _CSAF([-3.5, 1.2], [_CVI(1), _CVI(2)], 0.0),
                _LT(4.0),
            ),
        ],
        [_IN(0.5, 1.0), _IN(-1.3, 2.3), _IN(0.0, 1.0)],
    )
end

function _build_dmip_formulation()
    return Cerberus.DMIPFormulation(
        _build_polyhedron(),
        Cerberus.AbstractFormulater[],
        [_ZO(), nothing, _ZO()],
        _CSAF([1.0, -1.0], [_CVI(1), _CVI(2)], 0.0),
    )
end

function _build_gi_polyhedron()
    return Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(
                _CSAF([1.3, 3.7, 2.4], [_CVI(1), _CVI(2), _CVI(3)], 0.0),
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
        _CSAF(),
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

function _test_equal(u::Cerberus.CSAF, v::Cerberus.CSAF)
    u_terms = [Cerberus.index(u.indices[i]) => u.coeffs[i] for
     i in 1:length(u.indices)]
    v_terms = [Cerberus.index(v.indices[i]) => v.coeffs[i] for
     i in 1:length(v.indices)]
    u_t = sort(u_terms, lt = (x, y) -> x[1] < y[1])
    v_t = sort(v_terms, lt = (x, y) -> x[1] < y[1])
    @test u_t == v_t
    @test u.constant == v.constant
end

function _test_equal(u::_SAF, v::_SAF)
    return _test_equal(convert(Cerberus.CSAF, u), convert(Cerberus.CSAF, v))
end
