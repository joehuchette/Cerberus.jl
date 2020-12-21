@testset "build_base_model" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    node = Cerberus.Node()
    config = Cerberus.AlgorithmConfig()
    model = @inferred Cerberus.build_base_model(form, state, node, config)

    @test MOI.get(model, MOI.NumberOfVariables()) == 3
    @test MOI.get(model, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64},MOI.EqualTo{Float64}}()) == 1
    c1 = MOI.get(model, MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{Float64},MOI.EqualTo{Float64}}())[1]
    f1 = MOI.get(model, MOI.ConstraintFunction(), c1)
    @test f1.terms == [
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(2.0, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
    ]
    @test f1.constant == 0.0
    s1 = MOI.get(model, MOI.ConstraintSet(), c1)
    @test s1 == MOI.EqualTo(3.0)

    @test MOI.get(model, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}()) == 1
    c2 = MOI.get(model, MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}())[1]
    f2 = MOI.get(model, MOI.ConstraintFunction(), c2)
    @test f2.terms == [
        MOI.ScalarAffineTerm{Float64}(-3.5, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(1.2, _VI(2)),
    ]
    @test f2.constant == 0.0
    s2 = MOI.get(model, MOI.ConstraintSet(), c2)
    @test s2 == MOI.LessThan(4.0)
    @test MOI.get(model, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64},MOI.GreaterThan{Float64}}()) == 0

    @test MOI.get(model, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.Interval{Float64}}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(1)) == (0.5, 1.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(3)) == (0.0, 1.0)

    # TODO: Test obj, objsense
    @test MOI.get(model, MOI.ObjectiveSense()) == MOI.MIN_SENSE
    obj = MOI.get(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    @test obj.terms == [
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(-1.0, _VI(2)),
    ]
    @test obj.constant == 0.0
end

@testset "update_node_bounds!" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    node = Cerberus.Node()
    config = Cerberus.AlgorithmConfig()
    model = @inferred Cerberus.build_base_model(form, state, node, config)
    @test MOI.get(model, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.Interval{Float64}}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(1)) == (0.5, 1.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(3)) == (0.0, 1.0)

    node = Cerberus.Node([_VI(1)], [_VI(3)])
    @inferred Cerberus.update_node_bounds!(model, node)
    @test MOI.get(model, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.Interval{Float64}}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(1)) == (0.5, 0.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(2)) == (-1.3, 2.3)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(3)) == (1.0, 1.0)
end

@testset "MOI.optimize!" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    node = Cerberus.Node()
    config = Cerberus.AlgorithmConfig()
    model = Cerberus.build_base_model(form, state, node, config)
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(model, MOI.VariablePrimal(), MOI.VariableIndex(1)) ≈ 0.5
    @test MOI.get(model, MOI.VariablePrimal(), MOI.VariableIndex(2)) ≈ 1.25
    @test MOI.get(model, MOI.VariablePrimal(), MOI.VariableIndex(3)) ≈ 0.0
end

@testset "get_basis" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    node = Cerberus.Node()
    config = Cerberus.AlgorithmConfig()
    model = Cerberus.build_base_model(form, state, node, config)
    MOI.optimize!(model)
    @assert MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    basis = Cerberus.get_basis(model)
    @test basis == Dict{Any,MOI.BasisStatusCode}(
        MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(1) => MOI.NONBASIC_AT_LOWER,
        MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(2) => MOI.BASIC,
        MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(3) => MOI.NONBASIC_AT_LOWER,
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.EqualTo{Float64}}(2) => MOI.NONBASIC,
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(3) => MOI.BASIC,
    )
end

function _set_basis_model(basis::Cerberus.Basis)
        form = _build_dmip_formulation()
        state = Cerberus.CurrentState(form)
        parent_info = Cerberus.ParentInfo(-Inf, basis, nothing)
        node = Cerberus.Node([], [], parent_info)
        config = Cerberus.AlgorithmConfig()
        model = Cerberus.build_base_model(form, state, node, config)
        Cerberus.set_basis_if_available!(model, node.parent_info.basis)
        return model
end

@testset "set_basis_if_available!" begin
    # First, seed a suboptimal basis. This will disable presolve. It is only one pivot away from the optimal basis.
    let
        subopt_basis = Dict{Any,MOI.BasisStatusCode}(
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(1) => MOI.BASIC,
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(2) => MOI.NONBASIC_AT_LOWER,
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(3) => MOI.NONBASIC_AT_LOWER,
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.EqualTo{Float64}}(2) => MOI.NONBASIC,
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(3) => MOI.BASIC,
        )
        model = _set_basis_model(subopt_basis)
        MOI.optimize!(model)
        @test MOI.get(model, MOI.SimplexIterations()) == 1
    end

    # Now, seed the optimal basis. This will solve the problem without any simplex iterations.
    let
        opt_basis = Dict{Any,MOI.BasisStatusCode}(
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(1) => MOI.NONBASIC_AT_LOWER,
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(2) => MOI.BASIC,
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(3) => MOI.NONBASIC_AT_LOWER,
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.EqualTo{Float64}}(2) => MOI.NONBASIC,
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(3) => MOI.BASIC,
        )
        model = _set_basis_model(opt_basis)
        MOI.optimize!(model)
        @test MOI.get(model, MOI.SimplexIterations()) == 0
    end
end
