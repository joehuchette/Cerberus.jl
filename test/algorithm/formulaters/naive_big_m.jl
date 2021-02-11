function _build_disjunction()
    form = Cerberus.DMIPFormulation()
    Cerberus.add_variable(form)
    Cerberus.add_variable(form)
    Cerberus.set_bounds!(form, _CVI(1), _IN(-1.1, 1.1))
    Cerberus.set_bounds!(form, _CVI(2), _IN(-1.1, 1.1))
    x = [_SV(_VI(1)), _SV(_VI(2))]
    Cerberus.add_constraint(
        form,
        Cerberus.AffineConstraint(
            _CSAF([1.0, 1.0], [_CVI(1), _CVI(2)], 0.0),
            _LT(0.5),
        ),
    )
    Cerberus.add_constraint(
        form,
        Cerberus.AffineConstraint(
            _CSAF([1.0, -1.0], [_CVI(1), _CVI(2)], 0.0),
            _LT(0.6),
        ),
    )

    f_1 = 1.0 * x[1] + 1.0 * x[2]
    f_2 = 1.0 * x[1] - 1.0 * x[2]
    f_3 = 1.0 * x[1] + 0.5 * x[2]
    f_4 = 1.0 * x[1] - 0.5 * x[2]
    f = [convert(_CSAF, _f) for _f in (f_1, f_2, f_3, f_4)]

    lbs = [
        -Inf -Inf -Inf
        -Inf -Inf -Inf
        -Inf -Inf 0.5
        -Inf -Inf 0.5
    ]
    ubs = [
        0.0 Inf Inf
        Inf 0.0 Inf
        Inf Inf Inf
        Inf Inf Inf
    ]
    s = DisjunctiveConstraints.DisjunctiveSet(lbs, ubs)
    return form, Cerberus.Disjunction(f, s)
end

@testset "NaiveBigMFormulater" begin
    form, disjunction = _build_disjunction()
    activity_method = DisjunctiveConstraints.IntervalArithmetic()
    formulater = Cerberus.NaiveBigMFormulater(disjunction, activity_method)

    @testset "new_variables_to_attach" begin
        raw_indices = Cerberus.new_variables_to_attach(formulater)
        @test raw_indices == [_ZO(), _ZO(), _ZO()]
        for var_kind in raw_indices
            Cerberus.add_variable(form, var_kind)
        end
    end
    @testset "compute_disjunction_activity" begin
        let node = Cerberus.Node()
            pa, ni = Cerberus.compute_disjunction_activity(
                form,
                _CVI.([3, 4, 5]),
                node,
                CONFIG.int_tol,
            )
            @test pa == [false, false, false]
            @test ni == [true, true, true]
        end
        let node = Cerberus.Node(
                [Cerberus.BoundUpdate(_CVI(5), _LT(0.0))],
                [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))],
                2,
            )
            pa, ni = Cerberus.compute_disjunction_activity(
                form,
                _CVI.([3, 4, 5]),
                node,
                CONFIG.int_tol,
            )
            @test pa == [true, false, false]
            @test ni == [true, true, false]
        end
    end
end

@testset "formulate!" begin
    form = _build_formulation_with_single_disjunction()
    @assert length(form.disjunction_formulaters) == 1
    formulater, _ = first(form.disjunction_formulaters)

    let node = Cerberus.Node()
        state = Cerberus.CurrentState(form)
        Cerberus.populate_base_model!(state, form, node, CONFIG)
        Cerberus.apply_branchings!(state, node)
        @inferred Cerberus.formulate!(state, form, formulater, node, CONFIG)
        x = [_SV(Cerberus.instantiate(_CVI(i), state)) for i in 1:5]
        @assert [v.variable.value for v in x] == collect(1:5)

        expected_bounds =
            [(-1.5, 3.0), (0.0, 0.5), (0.0, 1.0), (0.0, 1.0), (0.0, 1.0)]
        expected_et_acs = [(1.0 * x[3] + 1.0 * x[4] + 1.0 * x[5], _ET(1.0))]
        expected_gt_acs = [
            (1.0 * x[1] + 1.0 * x[2], _GT(-0.5)),
            (1.0 * x[1] - 0.5 * x[3], _GT(-2.0)),
            (1.0 * x[1] + 0.5 * x[4], _GT(-1.0)),
            (1.0 * x[1] + 2.5 * x[5], _GT(+1.0)),
            (1.0 * x[1] + 1.0 * x[2] + 0.5 * x[3], _GT(-1.0)),
            (1.0 * x[2], _GT(0.0)),
            (-1.0 * x[1] + 1.0 * x[2] + 2.0 * x[5], _GT(-1.0)),
        ]
        expected_lt_acs = [
            (1.0 * x[1] - 4.0 * x[3], _LT(-1.0)),
            (1.0 * x[1] - 2.0 * x[4], _LT(+1.0)),
            (1.0 * x[1] - 1.0 * x[5], _LT(+2.0)),
            (1.0 * x[1] + 1.0 * x[2] - 4.5 * x[3], _LT(-1.0)),
            (1.0 * x[2] - 0.5 * x[4], _LT(0.0)),
            (-1.0 * x[1] + 1.0 * x[2] - 3.0 * x[5], _LT(-1.0)),
        ]

        _test_roundtrip_model(
            state.gurobi_model,
            expected_bounds,
            expected_lt_acs,
            expected_gt_acs,
            expected_et_acs,
        )
    end

    let node = Cerberus.Node(
            [Cerberus.BoundUpdate(_CVI(3), _LT(0.0))],
            Cerberus.BoundUpdate{_GT}[],
            1,
        )
        state = Cerberus.CurrentState(form)
        Cerberus.populate_base_model!(state, form, node, CONFIG)
        Cerberus.apply_branchings!(state, node)
        @inferred Cerberus.formulate!(state, form, formulater, node, CONFIG)
        x = [_SV(Cerberus.instantiate(_CVI(i), state)) for i in 1:5]
        @assert [v.variable.value for v in x] == collect(1:5)

        expected_bounds =
            [(-1.5, 3.0), (0.0, 0.5), (0.0, 0.0), (0.0, 1.0), (0.0, 1.0)]
        expected_et_acs = [(1.0 * x[4] + 1.0 * x[5], _ET(1.0))]
        expected_gt_acs = [
            (1.0 * x[1] + 1.0 * x[2], _GT(-0.5)),
            (1.0 * x[1] + 0.5 * x[4], _GT(-1.0)),
            (1.0 * x[1] + 2.5 * x[5], _GT(+1.0)),
            (1.0 * x[2], _GT(0.0)),
            (-1.0 * x[1] + 1.0 * x[2] + 2.0 * x[5], _GT(-1.0)),
        ]
        expected_lt_acs = [
            (1.0 * x[1] - 2.0 * x[4], _LT(+1.0)),
            (1.0 * x[1] - 1.0 * x[5], _LT(+2.0)),
            (1.0 * x[2] - 0.5 * x[4], _LT(0.0)),
            (-1.0 * x[1] + 1.0 * x[2] - 3.0 * x[5], _LT(-1.0)),
        ]

        _test_roundtrip_model(
            state.gurobi_model,
            expected_bounds,
            expected_lt_acs,
            expected_gt_acs,
            expected_et_acs,
        )
    end

    # TODO: Test cases where: 1) formulation is proven infeasible, and 2) disjunction is proven linear.
end
