const _VI = MOI.VariableIndex
const _SV = MOI.SingleVariable
const _VOV = MOI.VectorOfVariables
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
const _CCI = Cerberus.ConstraintIndex
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

function _is_equal(u::_CSAF, v::_CSAF)
    u_terms = [Cerberus.index(u.indices[i]) => u.coeffs[i] for
     i in 1:length(u.indices)]
    v_terms = [Cerberus.index(v.indices[i]) => v.coeffs[i] for
     i in 1:length(v.indices)]
    u_t = sort(u_terms, lt = (x, y) -> x[1] < y[1])
    v_t = sort(v_terms, lt = (x, y) -> x[1] < y[1])
    if !(u.constant ≈ v.constant)
        return false
    end
    u_idx = [t[1] for t in u_t]
    v_idx = [t[1] for t in v_t]
    if u_idx != v_idx
        return false
    end
    u_coeffs = [t[2] for t in u_t]
    v_coeffs = [t[2] for t in v_t]
    @assert length(u_coeffs) == length(v_coeffs)
    for i in 1:length(u_coeffs)
        if !(u_coeffs[i] ≈ v_coeffs[i])
            return false
        end
    end
    return true
end

function _is_equal(u::_SAF, v::_SAF)
    return _is_equal(convert(Cerberus.CSAF, u), convert(Cerberus.CSAF, v))
end

function _build_formulation_with_single_disjunction(
    method::DisjunctiveConstraints.AbstractDisjunctiveFormulation = DisjunctiveConstraints.NaiveBigM(
        DisjunctiveConstraints.IntervalArithmetic(),
    ),
)
    # min  y + 1.2
    # s.t. (-2 <= x <= -1 & y = -x - 1) or
    #          (-1 <= x <= +1 & y = 0) or
    #          (+1 <= x <= +2 & y = x - 1)
    #      x + y >= -0.5
    #      x in [-1.5, 3.0]
    #      y in [0.0, 0.5]
    form = Cerberus.DMIPFormulation(
        Cerberus.Polyhedron(
            [
                Cerberus.AffineConstraint(
                    _CSAF([1.0, 1.0], [_CVI(1), _CVI(2)], 0.0),
                    _GT(-0.5),
                ),
            ],
            [_IN(-1.5, 3.0), _IN(0.0, 0.5)],
        ),
        [nothing, nothing],
        _CSAF([1.0], [_CVI(2)], 1.2),
    )
    disjunction = Cerberus.Disjunction(
        [
            _CSAF([1.0], [_CVI(1)], 0.0),
            _CSAF([1.0, 1.0], [_CVI(1), _CVI(2)], 0.0),
            _CSAF([1.0], [_CVI(2)], 0.0),
            _CSAF([-1.0, 1.0], [_CVI(1), _CVI(2)], 0.0),
        ],
        DisjunctiveConstraints.DisjunctiveSet(
            [
                -2.0 -1.0 +1.0
                -1.0 -Inf -Inf
                -Inf 0.0 -Inf
                -Inf -Inf -1.0
            ],
            [
                -1.0 +1.0 +2.0
                -1.0 Inf Inf
                Inf 0.0 Inf
                Inf Inf -1.0
            ],
        ),
    )
    formulater = Cerberus.DisjunctiveFormulater(disjunction, method)
    Cerberus.attach_formulater!(form, formulater)
    return form
end

function _test_roundtrip_model(
    model::MOI.ModelLike,
    expected_bounds::Vector{Tuple{Float64,Float64}},
    expected_lt_acs::Vector{Tuple{_SAF,_LT}},
    expected_gt_acs::Vector{Tuple{_SAF,_GT}},
    expected_et_acs::Vector{Tuple{_SAF,_ET}},
)
    n = length(expected_bounds)
    @test MOI.get(model, MOI.NumberOfVariables()) == n
    for i in 1:n
        @test MOIU.get_bounds(model, Float64, _VI(i)) == expected_bounds[i]
    end

    expected_loc = Set([])
    if !isempty(expected_bounds)
        push!(expected_loc, (_SV, _IN))
    end
    if !isempty(expected_lt_acs)
        push!(expected_loc, (_SAF, _LT))
    end
    if !isempty(expected_gt_acs)
        push!(expected_loc, (_SAF, _GT))
    end
    if !isempty(expected_et_acs)
        push!(expected_loc, (_SAF, _ET))
    end
    @test Set(MOI.get(model, MOI.ListOfConstraints())) == expected_loc

    lt_constr_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_LT}())
    @test length(lt_constr_cis) == length(expected_lt_acs)
    for (i, ci) in enumerate(lt_constr_cis)
        f_actual = MOI.get(model, MOI.ConstraintFunction(), ci)
        s_actual = MOI.get(model, MOI.ConstraintSet(), ci)
        f_expected, s_expected = expected_lt_acs[i]
        @test _is_equal(f_actual, f_expected)
        @test s_actual == s_expected
    end

    gt_constr_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_GT}())
    @test length(gt_constr_cis) == length(expected_gt_acs)
    for (i, ci) in enumerate(gt_constr_cis)
        f_actual = MOI.get(model, MOI.ConstraintFunction(), ci)
        s_actual = MOI.get(model, MOI.ConstraintSet(), ci)
        f_expected, s_expected = expected_gt_acs[i]
        @test _is_equal(f_actual, f_expected)
        @test s_actual == s_expected
    end

    et_constr_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_ET}())
    @test length(et_constr_cis) == length(expected_et_acs)
    for (i, ci) in
        enumerate(MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_ET}()))
        f_actual = MOI.get(model, MOI.ConstraintFunction(), ci)
        s_actual = MOI.get(model, MOI.ConstraintSet(), ci)
        f_expected, s_expected = expected_et_acs[i]
        @test _is_equal(f_actual, f_expected)
        @test s_actual == s_expected
    end
end

function _CurrentState(; primal_bound = Inf)
    state = Cerberus.CurrentState(primal_bound = primal_bound)
    state.gurobi_env = GRB_ENV
    return state
end
