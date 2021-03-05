@testset "build_base_model" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState()
    node = Cerberus.Node()
    @inferred Cerberus.populate_lp_model!(state, form, node, CONFIG)
    model = state.gurobi_model

    @test MOI.get(model, MOI.NumberOfVariables()) == 3
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1
    c1 = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_ET}())[1]
    f1 = MOI.get(model, MOI.ConstraintFunction(), c1)
    _is_equal(f1, 1.0 * _SV(_VI(1)) + 2.1 * _SV(_VI(2)) + 3.0 * _SV(_VI(3)))
    s1 = MOI.get(model, MOI.ConstraintSet(), c1)
    @test s1 == _ET(3.0)

    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 1
    c2 = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_LT}())[1]
    f2 = MOI.get(model, MOI.ConstraintFunction(), c2)
    _is_equal(f2, -3.5 * _SV(_VI(1)) + 1.2 * _SV(_VI(2)))
    s2 = MOI.get(model, MOI.ConstraintSet(), c2)
    @test s2 == _LT(4.0)
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_GT}()) == 0

    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (0.5, 1.0)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (0.0, 1.0)

    # TODO: Test obj, objsense
    @test MOI.get(model, MOI.ObjectiveSense()) == MOI.MIN_SENSE
    obj = MOI.get(model, MOI.ObjectiveFunction{_SAF}())
    _is_equal(obj, 1.0 * _SV(_VI(1)) - 1.0 * _SV(_VI(2)))
end

@testset "update_node_bounds!" begin
    form = _build_dmip_formulation()
    state = _CurrentState()
    node = Cerberus.Node()
    @inferred Cerberus.populate_lp_model!(state, form, node, CONFIG)
    model = state.gurobi_model
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (0.5, 1.0)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (0.0, 1.0)

    node = Cerberus.Node(
        [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))],
        [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))],
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        2,
    )
    @inferred Cerberus.apply_branchings!(state, node)
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (1.0, 1.0)

    let f = _CSAF([1.2, 3.4], [_CVI(1), _CVI(2)], 5.6), s = _LT(7.8)
        bd = Cerberus.AffineConstraint(f, s)
        Cerberus.apply_branching!(node, bd)
        @inferred Cerberus.apply_branchings!(state, node)
        @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 2
        @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_GT}()) == 0
        @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1
        cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_LT}())
        # NOTE: cis[1] should be the constraint from the "base" formulation.
        ci = cis[2]
        f_rt = MOI.get(model, MOI.ConstraintFunction(), ci)
        s_rt = MOI.get(model, MOI.ConstraintSet(), ci)
        # Constraint added with MOIU.normalize_and_add_constraint, which shifts
        # constant over to set.
        @test _is_equal(f_rt, Cerberus.instantiate(f, state) - 5.6)
        @test s_rt == _LT(7.8 - 5.6)
    end

    let f = _CSAF([2.4, 6.4], [_CVI(3), _CVI(1)], 0.0), s = _GT(3.5)
        bd = Cerberus.AffineConstraint(f, s)
        Cerberus.apply_branching!(node, bd)
        @inferred Cerberus.apply_branchings!(state, node)
        # NOTE: We are testing here that the _LT general branching constraint
        # only gets added to the model once.
        @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 2
        @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_GT}()) == 1
        @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1
        cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_GT}())
        ci = cis[1]
        f_rt = MOI.get(model, MOI.ConstraintFunction(), ci)
        s_rt = MOI.get(model, MOI.ConstraintSet(), ci)
        @test _is_equal(f_rt, Cerberus.instantiate(f, state))
        @test s_rt == s
    end
end

@testset "reset_lp_model_upon_backtracking" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState()
    node = Cerberus.Node()
    Cerberus.populate_lp_model!(state, form, node, CONFIG)
    f_lt = _CSAF([1.2, 3.4], [_CVI(1), _CVI(2)], 0.0)
    s_lt = _LT(7.8)
    f_gt = _CSAF([2.4, 6.4], [_CVI(3), _CVI(1)], 0.0)
    s_gt = _GT(3.5)
    node_1 = Cerberus.Node(
        [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))],
        [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))],
        [Cerberus.AffineConstraint{_LT}(f_lt, s_lt)],
        [Cerberus.AffineConstraint{_GT}(f_gt, s_gt)],
        4,
    )
    Cerberus.apply_branchings!(state, node_1)

    model = state.gurobi_model
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (1.0, 1.0)
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 2
    let lt_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_LT}())
        lt_ci = lt_cis[2]
        f_lt_rt = MOI.get(model, MOI.ConstraintFunction(), lt_ci)
        s_lt_rt = MOI.get(model, MOI.ConstraintSet(), lt_ci)
        @test _is_equal(f_lt_rt, Cerberus.instantiate(f_lt, state))
        @test s_lt_rt == s_lt
    end
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_GT}()) == 1
    let gt_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_GT}())
        gt_ci = gt_cis[1]
        f_gt_rt = MOI.get(model, MOI.ConstraintFunction(), gt_ci)
        s_gt_rt = MOI.get(model, MOI.ConstraintSet(), gt_ci)
        @test _is_equal(f_gt_rt, Cerberus.instantiate(f_gt, state))
        @test s_gt_rt == s_gt
    end
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1

    node_2 = Cerberus.Node(
        [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))],
        Cerberus.BoundUpdate{_GT}[],
        Cerberus.AffineConstraint{_LT}[],
        [Cerberus.AffineConstraint{_GT}(f_gt, s_gt)],
        2,
    )
    Cerberus.reset_lp_model_upon_backtracking(state, form, node_2)
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(
        model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (0.0, 1.0)
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 1
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_GT}()) == 1
    let gt_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_GT}())
        gt_ci = gt_cis[1]
        f_gt_rt = MOI.get(model, MOI.ConstraintFunction(), gt_ci)
        s_gt_rt = MOI.get(model, MOI.ConstraintSet(), gt_ci)
        @test _is_equal(f_gt_rt, Cerberus.instantiate(f_gt, state))
        @test s_gt_rt == s_gt
    end
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1
end

@testset "apply_branchings!" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState()
    cs = state.constraint_state

    node = Cerberus.Node()
    Cerberus.populate_lp_model!(state, form, node, CONFIG)
    @test isempty(Cerberus._unattached_bounds(cs, node, _LT))
    @test isempty(Cerberus._unattached_bounds(cs, node, _GT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _LT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _GT))

    @inferred Cerberus.apply_branchings!(state, node)
    @test cs.branch_state.num_lt_branches == 0
    @test cs.branch_state.num_gt_branches == 0
    @test isempty(cs.branch_state.lt_general_constrs)
    @test isempty(cs.branch_state.gt_general_constrs)

    Cerberus.populate_lp_model!(state, form, node, CONFIG)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (0.5, 1.0)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (0.0, 1.0)

    bd_1 = Cerberus.BoundUpdate(_CVI(1), _GT(1.0))
    Cerberus.apply_branching!(node, bd_1)
    @test isempty(Cerberus._unattached_bounds(cs, node, _LT))
    @test Cerberus._unattached_bounds(cs, node, _GT) == [bd_1]
    @test isempty(Cerberus._unattached_constraints(cs, node, _LT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _GT))

    Cerberus.apply_branchings!(state, node)
    @test cs.branch_state.num_lt_branches == 0
    @test cs.branch_state.num_gt_branches == 1
    @test isempty(cs.branch_state.lt_general_constrs)
    @test isempty(cs.branch_state.gt_general_constrs)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (1.0, 1.0)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (0.0, 1.0)
    @test isempty(Cerberus._unattached_bounds(cs, node, _LT))
    @test isempty(Cerberus._unattached_bounds(cs, node, _GT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _LT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _GT))

    bd_2 = Cerberus.BoundUpdate(_CVI(3), _LT(0.0))
    Cerberus.apply_branching!(node, bd_2)
    @test Cerberus._unattached_bounds(cs, node, _LT) == [bd_2]
    @test isempty(Cerberus._unattached_bounds(cs, node, _GT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _LT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _GT))

    Cerberus.apply_branchings!(state, node)
    @test cs.branch_state.num_lt_branches == 1
    @test cs.branch_state.num_gt_branches == 1
    @test isempty(cs.branch_state.lt_general_constrs)
    @test isempty(cs.branch_state.gt_general_constrs)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (1.0, 1.0)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (0.0, 0.0)
    @test isempty(Cerberus._unattached_bounds(cs, node, _LT))
    @test isempty(Cerberus._unattached_bounds(cs, node, _GT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _LT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _GT))

    # Now we jump across the tree to a different node at the same depth.
    # Notably, we do not update the constraint_state. In particular, we still
    # believe that there has only been two variable branches. Therefore, the
    # model will still have the same bounds as above, and will NOT correspond
    # to the bounds in node below.
    node = Cerberus.Node()
    Cerberus.apply_branching!(node, Cerberus.BoundUpdate(_CVI(3), _GT(1.0)))
    Cerberus.apply_branching!(node, Cerberus.BoundUpdate(_CVI(1), _LT(0.0)))
    @test isempty(Cerberus._unattached_bounds(cs, node, _LT))
    @test isempty(Cerberus._unattached_bounds(cs, node, _GT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _LT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _GT))

    Cerberus.apply_branchings!(state, node)
    @test cs.branch_state.num_lt_branches == 1
    @test cs.branch_state.num_gt_branches == 1
    @test isempty(cs.branch_state.lt_general_constrs)
    @test isempty(cs.branch_state.gt_general_constrs)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(1), state),
    ) == (1.0, 1.0)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(2), state),
    ) == (-1.3, 2.3)
    @test MOIU.get_bounds(
        state.gurobi_model,
        Float64,
        Cerberus.instantiate(_CVI(3), state),
    ) == (0.0, 0.0)
    @test isempty(Cerberus._unattached_bounds(cs, node, _LT))
    @test isempty(Cerberus._unattached_bounds(cs, node, _GT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _LT))
    @test isempty(Cerberus._unattached_constraints(cs, node, _GT))

    lt_gen_1 = Cerberus.AffineConstraint(2.3 * _SV(_VI(1)), _LT(2.3))
    lt_gen_2 = Cerberus.AffineConstraint(2.5 * _SV(_VI(3)), _LT(2.5))
    gt_gen = Cerberus.AffineConstraint(2.4 * _SV(_VI(2)), _GT(2.4))
    Cerberus.apply_branching!(node, lt_gen_1)
    Cerberus.apply_branching!(node, lt_gen_2)
    Cerberus.apply_branching!(node, gt_gen)
    @test isempty(Cerberus._unattached_bounds(cs, node, _LT))
    @test isempty(Cerberus._unattached_bounds(cs, node, _GT))
    @test Cerberus._unattached_constraints(cs, node, _LT) ==
          [lt_gen_1, lt_gen_2]
    @test Cerberus._unattached_constraints(cs, node, _GT) == [gt_gen]

    Cerberus.apply_branchings!(state, node)
    @test cs.branch_state.num_lt_branches == 1
    @test cs.branch_state.num_gt_branches == 1
    @test length(cs.branch_state.lt_general_constrs) == 2
    @test length(cs.branch_state.gt_general_constrs) == 1
    @test MOI.get(state.gurobi_model, MOI.NumberOfConstraints{_SAF,_LT}()) == 3
    @test MOI.get(state.gurobi_model, MOI.NumberOfConstraints{_SAF,_GT}()) == 1
end

@testset "formulate_disjunctions!" begin
    form = _build_formulation_with_single_disjunction(
        DisjunctiveConstraints.NaiveBigM(
            DisjunctiveConstraints.IntervalArithmetic(),
        ),
    )
    let node = Cerberus.Node()
        state = Cerberus.CurrentState()
        Cerberus.populate_lp_model!(state, form, node, CONFIG)
        Cerberus.apply_branchings!(state, node)
        @inferred Cerberus.formulate_disjunctions!(state, form, node, CONFIG)
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
        state = Cerberus.CurrentState()
        Cerberus.populate_lp_model!(state, form, node, CONFIG)
        Cerberus.apply_branchings!(state, node)
        @inferred Cerberus.formulate_disjunctions!(state, form, node, CONFIG)
        x = [_SV(Cerberus.instantiate(_CVI(i), state)) for i in 1:5]
        @assert [v.variable.value for v in x] == collect(1:5)

        expected_bounds =
            [(-1.5, 3.0), (0.0, 0.5), (0.0, 0.0), (0.0, 1.0), (0.0, 1.0)]
        expected_et_acs = [(1.0 * x[3] + 1.0 * x[4] + 1.0 * x[5], _ET(1.0))]
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

@testset "MOI.optimize!" begin
    form = _build_dmip_formulation()
    state = _CurrentState()
    node = Cerberus.Node()
    Cerberus.populate_lp_model!(state, form, node, CONFIG)
    model = state.gurobi_model
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(model, MOI.VariablePrimal(), _VI(1)) ≈ 0.5
    @test MOI.get(model, MOI.VariablePrimal(), _VI(2)) ≈ 2.5 / 2.1
    @test MOI.get(model, MOI.VariablePrimal(), _VI(3)) ≈ 0.0
end

@testset "_fill_solution!" begin
    form = _build_dmip_formulation()
    state = _CurrentState()
    node = Cerberus.Node()
    Cerberus.populate_lp_model!(state, form, node, CONFIG)
    model = state.gurobi_model
    MOI.optimize!(model)
    @assert MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @inferred Cerberus._update_lp_solution!(state, form)
    x = state.current_solution
    @test length(x) == 3
    @test x ≈ [1 / 2, 2.5 / 2.1, 0.0]
end

@testset "get_basis" begin
    form = _build_dmip_formulation()
    state = _CurrentState()
    node = Cerberus.Node()
    Cerberus.populate_lp_model!(state, form, node, CONFIG)
    model = state.gurobi_model
    MOI.optimize!(model)
    @assert MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    true_basis = @inferred Cerberus.get_basis(state)
    expected_basis = Cerberus.Basis(
        [MOI.NONBASIC_AT_LOWER, MOI.BASIC, MOI.NONBASIC_AT_LOWER],
        [MOI.BASIC],
        MOI.BasisStatusCode[],
        [MOI.NONBASIC],
        MOI.BasisStatusCode[],
        MOI.BasisStatusCode[],
    )
    @test true_basis.base_var_constrs == expected_basis.base_var_constrs
    @test true_basis.base_lt_constrs == expected_basis.base_lt_constrs
    @test true_basis.base_gt_constrs == expected_basis.base_gt_constrs
    @test true_basis.base_et_constrs == expected_basis.base_et_constrs
    @test true_basis.branch_lt_constrs == expected_basis.branch_lt_constrs
    @test true_basis.branch_gt_constrs == expected_basis.branch_gt_constrs
end

function _set_basis_model(basis::Cerberus.Basis)
    form = _build_dmip_formulation()
    state = _CurrentState()
    node = Cerberus.Node(
        Cerberus.BoundUpdate{_LT}[],
        Cerberus.BoundUpdate{_GT}[],
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        0,
        -Inf,
    )
    Cerberus.populate_lp_model!(state, form, node, CONFIG)
    state.warm_starts[node] = basis
    Cerberus.set_basis_if_available!(state, node)
    return state.gurobi_model
end

@testset "set_basis_if_available!" begin
    # First, seed a suboptimal basis. This will disable presolve. It is only one pivot away from the optimal basis.
    let
        subopt_basis = Cerberus.Basis(
            [MOI.BASIC, MOI.NONBASIC_AT_LOWER, MOI.NONBASIC_AT_LOWER],
            [MOI.BASIC],
            MOI.BasisStatusCode[],
            [MOI.NONBASIC],
            MOI.BasisStatusCode[],
            MOI.BasisStatusCode[],
        )
        model = _set_basis_model(subopt_basis)
        MOI.optimize!(model)
        @test MOI.get(model, MOI.SimplexIterations()) == 1
    end

    # Now, seed the optimal basis. This will solve the problem without any simplex iterations.
    let
        opt_basis = Cerberus.Basis(
            [MOI.NONBASIC_AT_LOWER, MOI.BASIC, MOI.NONBASIC_AT_LOWER],
            [MOI.BASIC],
            MOI.BasisStatusCode[],
            [MOI.NONBASIC],
            MOI.BasisStatusCode[],
            MOI.BasisStatusCode[],
        )
        model = _set_basis_model(opt_basis)
        MOI.optimize!(model)
        @test MOI.get(model, MOI.SimplexIterations()) == 0
    end
end
