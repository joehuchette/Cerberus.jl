@testset "build_base_model" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form, CONFIG)
    node = Cerberus.Node()
    @inferred Cerberus.populate_base_model!(state, form, node, CONFIG)
    model = state.gurobi_model

    @test MOI.get(model, MOI.NumberOfVariables()) == 3
    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_ET}()) == 1
    c1 = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_ET}())[1]
    f1 = MOI.get(model, MOI.ConstraintFunction(), c1)
    @test f1.terms == [
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(2.1, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
    ]
    @test f1.constant == 0.0
    s1 = MOI.get(model, MOI.ConstraintSet(), c1)
    @test s1 == _ET(3.0)

    @test MOI.get(model, MOI.NumberOfConstraints{_SAF,_LT}()) == 1
    c2 = MOI.get(model, MOI.ListOfConstraintIndices{_SAF,_LT}())[1]
    f2 = MOI.get(model, MOI.ConstraintFunction(), c2)
    @test f2.terms == [
        MOI.ScalarAffineTerm{Float64}(-3.5, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(1.2, _VI(2)),
    ]
    @test f2.constant == 0.0
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
    @test obj.terms == [
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(-1.0, _VI(2)),
    ]
    @test obj.constant == 0.0
end

@testset "update_node_bounds!" begin
    form = _build_dmip_formulation()
    state = _CurrentState(form, CONFIG)
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
    @inferred Cerberus.apply_branchings!(model, state, node)
    @test MOI.get(model, MOI.NumberOfConstraints{_SV,_IN}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, _VI(1)) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, _VI(3)) == (1.0, 1.0)
end

@testset "MOI.optimize!" begin
    form = _build_dmip_formulation()
    state = _CurrentState(form, CONFIG)
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
    state = _CurrentState(form, CONFIG)
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
    state = _CurrentState(form, CONFIG)
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
    state = _CurrentState(form, CONFIG)
    node = Cerberus.Node(
        Cerberus.BoundDiff(),
        Cerberus.BoundDiff(),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        0,
        -Inf,
    )
    Cerberus.populate_base_model!(state, form, node, CONFIG)
    model = state.gurobi_model
    Cerberus._set_basis!(model, state.constraint_state, basis)
    return model
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
