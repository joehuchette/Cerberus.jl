@testset "upbranch and downbranch" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    db = @inferred Cerberus.down_branch(node, _VI(1))
    @test db.vars_branched_to_zero == [_VI(1)]
    @test db.vars_branched_to_one == _VI[]

    ub = @inferred Cerberus.up_branch(node, _VI(2))
    @test ub.vars_branched_to_zero == _VI[]
    @test ub.vars_branched_to_one == [_VI(2)]
end

@testset "MostInfeasible" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    x = [0.6, 0.7, 0.1]
    cost = 1.2
    config = Cerberus.AlgorithmConfig()
    result = Cerberus.NodeResult(cost, 12, x)
    n1, n2 = @inferred Cerberus.branch(fm, Cerberus.MostInfeasible(), node, result, config)
    @test n1.vars_branched_to_zero == _VI[]
    @test n1.vars_branched_to_one == [_VI(1)]
    @test n1.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

    @test n2.vars_branched_to_zero == [_VI(1)]
    @test n2.vars_branched_to_one == _VI[]
    @test n2.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)


    x2 = Dict(_VI(1) => 1.0, _VI(2) => 0.7, _VI(3) => 0.1)
    result.x = x2
    n3, n4 = @inferred Cerberus.branch(fm, Cerberus.MostInfeasible(), n2, result, config)
    @test n3.vars_branched_to_zero == [_VI(1), _VI(3)]
    @test n3.vars_branched_to_one == _VI[]
    @test n3.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

    @test n4.vars_branched_to_zero == [_VI(1)]
    @test n4.vars_branched_to_one == [_VI(3)]
    @test n4.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

    # Nothing to branch on, should throw. Really, should have pruned by integrality before.
    x3 = Dict(_VI(1) => 1.0, _VI(2) => 0.7, _VI(3) => 0.0)
    result.x = x3
    @test_throws AssertionError Cerberus.branch(fm, Cerberus.MostInfeasible(), n4, result, config)
end
