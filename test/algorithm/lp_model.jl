@testset "build_base_model" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    node = Cerberus.Node()
    @inferred Cerberus.populate_base_model!(state, form, node, CONFIG)
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
    @test MOI.Utilities.get_bounds(model, Float64, _VI(1)) == (0.5, 1.0)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(3)) == (0.0, 1.0)

    # TODO: Test obj, objsense
    @test MOI.get(model, MOI.ObjectiveSense()) == MOI.MIN_SENSE
    obj = MOI.get(model, MOI.ObjectiveFunction{_SAF}())
    _is_equal(obj, 1.0 * _SV(_VI(1)) - 1.0 * _SV(_VI(2)))
end

@testset "update_node_bounds!" begin
    form = _build_dmip_formulation()
    state = _CurrentState(form)
    node = Cerberus.Node()
    @inferred Cerberus.populate_base_model!(state, form, node, CONFIG)
    model = state.gurobi_model
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, _VI(1)) == (0.5, 1.0)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(3)) == (0.0, 1.0)

    node = Cerberus.Node(
        Cerberus.BoundDiff(_VI(3) => 1),
        Cerberus.BoundDiff(_VI(1) => 0),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        2,
    )
    @inferred Cerberus.apply_branchings!(state, node)
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, _VI(1)) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(3)) == (1.0, 1.0)

    let f = _SAF([_SAT(1.2, _VI(1)), _SAT(3.4, _VI(2))], 5.6), s = _LT(7.8)
        bd = Cerberus.BranchingDecision(f, s)
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
        _is_equal(f_rt, f - 5.6)
        @test s_rt == _LT(7.8 - 5.6)
    end

    let f = _SAF([_SAT(2.4, _VI(3)), _SAT(6.4, _VI(1))], 0.0), s = _GT(3.5)
        bd = Cerberus.BranchingDecision(f, s)
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
        _is_equal(f_rt, f)
        @test s_rt == s
    end
end

@testset "reset_base_formulation_upon_backtracking!" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    node = Cerberus.Node()
    Cerberus.populate_base_model!(state, form, node, CONFIG)
    f_lt = _SAF([_SAT(1.2, _VI(1)), _SAT(3.4, _VI(2))], 0.0)
    s_lt = _LT(7.8)
    f_gt = _SAF([_SAT(2.4, _VI(3)), _SAT(6.4, _VI(1))], 0.0)
    s_gt = _GT(3.5)
    node_1 = Cerberus.Node(
        Cerberus.BoundDiff(_VI(3) => 1),
        Cerberus.BoundDiff(_VI(1) => 0),
        [Cerberus.AffineConstraint{_LT}(f_lt, s_lt)],
        [Cerberus.AffineConstraint{_GT}(f_gt, s_gt)],
        4,
    )
    Cerberus.apply_branchings!(state, node_1)

    model = state.gurobi_model
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, _VI(1)) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(3)) == (1.0, 1.0)
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 2
    let lt_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_LT}())
        lt_ci = lt_cis[2]
        f_lt_rt = MOI.get(model, MOI.ConstraintFunction(), lt_ci)
        s_lt_rt = MOI.get(model, MOI.ConstraintSet(), lt_ci)
        _is_equal(f_lt_rt, f_lt)
        @test s_lt_rt == s_lt
    end
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_GT}()) == 1
    let gt_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_GT}())
        gt_ci = gt_cis[1]
        f_gt_rt = MOI.get(model, MOI.ConstraintFunction(), gt_ci)
        s_gt_rt = MOI.get(model, MOI.ConstraintSet(), gt_ci)
        _is_equal(f_gt_rt, f_gt)
        @test s_gt_rt == s_gt
    end
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1

    node_2 = Cerberus.Node(
        Cerberus.BoundDiff(),
        Cerberus.BoundDiff(_VI(1) => 0),
        Cerberus.AffineConstraint{_LT}[],
        [Cerberus.AffineConstraint{_GT}(f_gt, s_gt)],
        2,
    )
    Cerberus.reset_base_formulation_upon_backtracking!(state, form, node_2)
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, _VI(1)) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(3)) == (0.0, 1.0)
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 1
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_GT}()) == 1
    let gt_cis = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_GT}())
        gt_ci = gt_cis[1]
        f_gt_rt = MOI.get(model, MOI.ConstraintFunction(), gt_ci)
        s_gt_rt = MOI.get(model, MOI.ConstraintSet(), gt_ci)
        _is_equal(f_gt_rt, f_gt)
        @test s_gt_rt == s_gt
    end
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1
end

@testset "MOI.optimize!" begin
    form = _build_dmip_formulation()
    state = _CurrentState(form)
    node = Cerberus.Node()
    Cerberus.populate_base_model!(state, form, node, CONFIG)
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
    state = _CurrentState(form)
    node = Cerberus.Node()
    Cerberus.populate_base_model!(state, form, node, CONFIG)
    model = state.gurobi_model
    MOI.optimize!(model)
    @assert MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    x = @inferred Cerberus._get_lp_solution!(model)
    @test length(x) == 3
    @test x ≈ [1 / 2, 2.5 / 2.1, 0.0]
end

@testset "get_basis" begin
    form = _build_dmip_formulation()
    state = _CurrentState(form)
    node = Cerberus.Node()
    Cerberus.populate_base_model!(state, form, node, CONFIG)
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
    state = _CurrentState(form)
    node = Cerberus.Node(
        Cerberus.BoundDiff(),
        Cerberus.BoundDiff(),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        0,
        -Inf,
    )
    Cerberus.populate_base_model!(state, form, node, CONFIG)
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
