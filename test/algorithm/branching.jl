@testset "upbranch and downbranch" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    result = Cerberus.NodeResult(nothing, NaN, nothing, 12)
    db = @inferred Cerberus.down_branch(node, result, _VI(1))
    @test db.vars_branched_to_zero == [_VI(1)]
    @test db.vars_branched_to_one == _VI[]

    ub = @inferred Cerberus.up_branch(node, result, _VI(2))
    @test ub.vars_branched_to_zero == _VI[]
    @test ub.vars_branched_to_one == [_VI(2)]
end

@testset "MostInfeasible" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    x = [0.6, 0.7, 0.1]
    cost = 1.2
    config = Cerberus.AlgorithmConfig()
    state = Cerberus.CurrentState(fm)
    result = Cerberus.NodeResult(x, cost, nothing, 12)
    n1, n2 = @inferred Cerberus.branch(fm, Cerberus.MostInfeasible(), state, node, result, config)
    @test n1.vars_branched_to_zero == _VI[]
    @test n1.vars_branched_to_one == [_VI(1)]
    @test n1.parent_info.dual_bound == cost
    @test n1.parent_info.basis === nothing

    @test n2.vars_branched_to_zero == [_VI(1)]
    @test n2.vars_branched_to_one == _VI[]
    @test n2.parent_info.dual_bound == cost
    @test n2.parent_info.basis === nothing

    x2 = [1.0, 0.7, 0.1]
    result.x = x2
    n3, n4 = @inferred Cerberus.branch(fm, Cerberus.MostInfeasible(), state, n2, result, config)
    @test n3.vars_branched_to_zero == [_VI(1), _VI(3)]
    @test n3.vars_branched_to_one == _VI[]
    @test n3.parent_info.dual_bound == cost
    @test n3.parent_info.basis === nothing

    @test n4.vars_branched_to_zero == [_VI(1)]
    @test n4.vars_branched_to_one == [_VI(3)]
    @test n4.parent_info.dual_bound == cost
    @test n4.parent_info.basis === nothing

    # Nothing to branch on, should throw. Really, should have pruned by integrality before.
    x3 = [1.0, 0.7, 0.0]
    result.x = x3
    @test_throws AssertionError Cerberus.branch(fm, Cerberus.MostInfeasible(), state, n4, result, config)
end
