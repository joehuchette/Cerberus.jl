@testset "NodeResult" begin
    cost = 5.6
    x = [1.2, 3.4]
    x_dict = _vec_to_dict(x)
    simplex_iters = 3
    depth = 12
    int_infeas = 4
    basis = Cerberus.Basis()
    model = nothing
    nr1 =
        @inferred Cerberus.NodeResult(cost, x_dict, simplex_iters, depth, int_infeas, basis, model)
    @test nr1.cost == cost
    @test nr1.x == x_dict
    @test nr1.simplex_iters == simplex_iters
    @test nr1.depth == depth
    @test nr1.int_infeas == int_infeas
    @test nr1.basis == basis
    @test nr1.model == model

    basis = Cerberus.Basis(
        _VI(1) => MOI.BASIC,
        _VI(2) => MOI.BASIC,
        _CI{_SAF,_GT}(1) => MOI.NONBASIC,
        _CI{_SAF,_LT}(2) => MOI.NONBASIC,
        _CI{_SAF,_LT}(3) => MOI.NONBASIC,
    )
    nr2 =
        @inferred Cerberus.NodeResult(cost, x_dict, simplex_iters, depth, int_infeas, basis, model)
    @test nr2.cost == cost
    @test nr2.x == x_dict
    @test nr2.simplex_iters == simplex_iters
    @test nr2.depth == depth
    @test nr2.int_infeas == int_infeas
    @test nr2.basis == basis
    @test nr2.model == model

    @testset "empty!" begin
        cost = 5.6
        x = Dict(_VI(1) => 15.7)
        si = 12
        dp = 5
        ii = 2
        basis = Dict{Any,MOI.BasisStatusCode}(_CI{_SV,_IN}(1) => MOI.BASIC)
        model = Gurobi.Optimizer()
        nr = Cerberus.NodeResult(cost, x, si, dp, ii, basis, model)
        @test nr.cost == cost
        @test nr.x == x
        @test nr.simplex_iters == si
        @test nr.depth == dp
        @test nr.int_infeas == ii
        @test nr.basis == basis
        @test nr.model === model
        empty!(nr)
        @test isnan(nr.cost)
        @test nr.simplex_iters == 0
        @test nr.depth == 0
        @test nr.int_infeas == 0
        @test isempty(nr.x)
        @test isempty(nr.basis)
        @test nr.model === nothing
    end
end

@testset "CurrentState" begin
    fm = _build_dmip_formulation()

    pb_float = 12.4
    pb_int = 12

    cs1 = @inferred _CurrentState()
    cs2 = @inferred _CurrentState(pb_float)
    cs3 = @inferred _CurrentState(pb_int)

    @test length(cs1.tree) == 1
    @test length(cs2.tree) == 1
    @test length(cs3.tree) == 1

    @test _is_root_node(Cerberus.pop_node!(cs1.tree))
    @test _is_root_node(Cerberus.pop_node!(cs2.tree))
    @test _is_root_node(Cerberus.pop_node!(cs3.tree))

    @test cs1.total_node_count == 0
    @test cs2.total_node_count == 0
    @test cs3.total_node_count == 0

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
