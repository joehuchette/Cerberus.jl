@testset "NodeResult" begin
    x = [1.2, 3.4]
    x_dict = Dict(_VI(i) => x[i] for i in 1:length(x))
    cost = 5.6
    simplex_iters = 3
    basis = nothing
    model = nothing
    nr1 = @inferred Cerberus.NodeResult(cost, simplex_iters, x, basis, model)
    @test nr1.x == x_dict
    @test nr1.cost == cost
    @test nr1.simplex_iters == simplex_iters
    @test nr1.basis == basis
    @test nr1.model == model

    basis = Cerberus.Basis(
        _VI(1) => MOI.BASIC,
        _VI(2) => MOI.BASIC,
        _CI(1) => MOI.NONBASIC,
        _CI(2) => MOI.NONBASIC,
        _CI(3) => MOI.NONBASIC,
    )
    nr2 = @inferred Cerberus.NodeResult(cost, simplex_iters, x, basis, model)
    @test nr2.x == x_dict
    @test nr2.cost == cost
    @test nr2.simplex_iters == simplex_iters
    @test nr2.basis == basis
    @test nr2.model == model

    simplex_iters_bad = -1
    @test_throws AssertionError Cerberus.NodeResult(cost, simplex_iters_bad, x, nothing, nothing)
end

@testset "CurrentState" begin
    fm = _build_dmip_formulation()

    pb_float = 12.4
    pb_int = 12

    cs1 = @inferred Cerberus.CurrentState()
    cs2 = @inferred Cerberus.CurrentState(pb_float)
    cs3 = @inferred Cerberus.CurrentState(pb_int)

    @test isempty(cs1.tree)
    @test isempty(cs2.tree)
    @test isempty(cs3.tree)

    @test cs1.enumerated_node_count == 0
    @test cs2.enumerated_node_count == 0
    @test cs3.enumerated_node_count == 0

    @test cs1.primal_bound == Inf
    @test cs2.primal_bound == pb_float
    @test cs3.primal_bound == pb_int

    @test cs1.dual_bound == -Inf
    @test cs2.dual_bound == -Inf
    @test cs3.dual_bound == -Inf

    @test isempty(cs1.best_solution)
    @test isempty(cs2.best_solution)
    @test isempty(cs3.best_solution)

    @test cs1.total_simplex_iters == 0
    @test cs2.total_simplex_iters == 0
    @test cs3.total_simplex_iters == 0
end
