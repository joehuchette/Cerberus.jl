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
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(1)) == (-1.0, 1.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(2)) == (-Inf, 2.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(3)) == (-Inf, Inf)

    # TODO: Test obj, objsense


end

@testset "update_node_bounds!" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    node = Cerberus.Node()
    config = Cerberus.AlgorithmConfig()
    model = @inferred Cerberus.build_base_model(form, state, node, config)
    @test MOI.get(model, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.Interval{Float64}}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(1)) == (-1.0, 1.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(2)) == (-Inf, 2.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(3)) == (-Inf, Inf)

    node = Cerberus.Node([_VI(1)], [_VI(3)])
    @inferred Cerberus.update_node_bounds!(model, node)
    @test MOI.get(model, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.Interval{Float64}}()) == 3
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(1)) == (-1.0, 0.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(2)) == (-Inf, 2.0)
    @test MOI.Utilities.get_bounds(model, Float64, MOI.VariableIndex(3)) == (1.0, Inf)
end

@testset "get_basis" begin

end