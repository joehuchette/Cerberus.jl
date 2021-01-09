const _VI = MOI.VariableIndex
const _SV = MOI.SingleVariable
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

function _build_relaxation()
    poly = _build_polyhedron()
    v = [_SV(_VI(i)) for i in 1:3]
    return Cerberus.LPRelaxation(_build_polyhedron(), 1.0 * v[1] - 1.0 * v[2])
end

function _build_dmip_formulation()
    return Cerberus.DMIPFormulation(
        _build_relaxation(),
        Cerberus.AbstractFormulater[],
        [_ZO(), nothing, _ZO()],
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
        Cerberus.LPRelaxation(_build_gi_polyhedron(), convert(_SAF, 0.0)),
        Cerberus.AbstractFormulater[],
        [nothing, _ZO(), _GI()],
    )
end

function _Basis(d::Dict)
    basis = Cerberus.Basis()
    for (k, v) in d
        if typeof(k) == _CI{_SAF,_LT}
            basis.lt_constrs[k] = v
        elseif typeof(k) == _CI{_SAF,_GT}
            basis.gt_constrs[k] = v
        elseif typeof(k) == _CI{_SAF,_ET}
            basis.et_constrs[k] = v
        else
            @assert typeof(k) == _CI{_SV,_IN}
            basis.var_constrs[k] = v
        end
    end
    return basis
end
