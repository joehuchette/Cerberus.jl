@testset "formulate!" begin
    for method in (
        DisjunctiveConstraints.NaiveBigM(
            DisjunctiveConstraints.IntervalArithmetic(),
        ),
    )
        @testset "$method" begin
            form = _build_formulation_with_single_disjunction(method)
            @assert length(form.disjunction_formulaters) == 1
            formulater, _ = first(form.disjunction_formulaters)

            let node = Cerberus.Node()
                state = Cerberus.CurrentState()
                Cerberus.populate_base_model!(state, form, node, CONFIG)
                Cerberus.apply_branchings!(state, node)
                @inferred Cerberus.formulate!(
                    state,
                    form,
                    formulater,
                    node,
                    CONFIG,
                )
                x = [_SV(Cerberus.instantiate(_CVI(i), state)) for i in 1:5]
                @assert [v.variable.value for v in x] == collect(1:5)

                expected_bounds = [
                    (-1.5, 3.0),
                    (0.0, 0.5),
                    (0.0, 1.0),
                    (0.0, 1.0),
                    (0.0, 1.0),
                ]
                expected_et_acs =
                    [(1.0 * x[3] + 1.0 * x[4] + 1.0 * x[5], _ET(1.0))]
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
                state = Cerberus.CurrentState()
                Cerberus.populate_base_model!(state, form, node, CONFIG)
                Cerberus.apply_branchings!(state, node)
                @inferred Cerberus.formulate!(
                    state,
                    form,
                    formulater,
                    node,
                    CONFIG,
                )
                x = [_SV(Cerberus.instantiate(_CVI(i), state)) for i in 1:5]
                @assert [v.variable.value for v in x] == collect(1:5)

                expected_bounds = [
                    (-1.5, 3.0),
                    (0.0, 0.5),
                    (0.0, 0.0),
                    (0.0, 1.0),
                    (0.0, 1.0),
                ]
                expected_et_acs =
                    [(1.0 * x[3] + 1.0 * x[4] + 1.0 * x[5], _ET(1.0))]
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
        end
    end
    # TODO: Test cases where: 1) formulation is proven infeasible, and 2) disjunction is proven linear.
end
