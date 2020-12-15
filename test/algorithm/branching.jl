@testset "upbranch and downbranch" begin
    pr = _build_formulation()
    node = Cerberus.Node()
    result = Cerberus.NodeResult(nothing, NaN, nothing, 12)
    db = @inferred Cerberus.down_branch(node, result, 1)
    @test db.vars_branched_to_zero == Set{Int}([1])
    @test db.vars_branched_to_one == Set{Int}([])

    ub = @inferred Cerberus.up_branch(node, result, 2)
    @test ub.vars_branched_to_zero == Set{Int}([])
    @test ub.vars_branched_to_one == Set{Int}([2])
end

@testset "MostInfeasible" begin
    pr = _build_problem()
    node = Cerberus.Node()
    x = [0.6, 0.7, 0.1]
    cost = 1.2
    config = Cerberus.AlgorithmConfig()
    state = Cerberus.CurrentState(pr)
    result = Cerberus.NodeResult(x, cost, nothing, 12)
    n1, n2 = @inferred Cerberus.branch(pr, Cerberus.MostInfeasible(), state, node, result)
    @test n1.vars_branched_to_zero == Set{Int}([])
    @test n1.vars_branched_to_one == Set{Int}([1])
    @test n1.parent_dual_bound == cost
    @test n1.basis === nothing

    @test n2.vars_branched_to_zero == Set{Int}([1])
    @test n2.vars_branched_to_one == Set{Int}([])
    @test n2.parent_dual_bound == cost
    @test n2.basis === nothing

    x2 = [1.0, 0.7, 0.1]
    result.x = x2
    n3, n4 = @inferred Cerberus.branch(pr, Cerberus.MostInfeasible(), state, n2, result)
    @test n3.vars_branched_to_zero == Set{Int}([1, 3])
    @test n3.vars_branched_to_one == Set{Int}([])
    @test n3.parent_dual_bound == cost
    @test n3.basis === nothing

    @test n4.vars_branched_to_zero == Set{Int}([1])
    @test n4.vars_branched_to_one == Set{Int}([3])
    @test n4.parent_dual_bound == cost
    @test n4.basis === nothing
end
