@testset "NodeResult" begin
    cost = 5.6
    x = [1.2, 3.4]
    x_dict = _vec_to_dict(x)
    simplex_iters = 3
    depth = 12
    int_infeas = 4
    let nr1 = @inferred Cerberus.NodeResult(
            cost,
            x_dict,
            simplex_iters,
            depth,
            int_infeas,
            Cerberus.IncrementalData(Cerberus.NO_INCREMENTALISM),
        )
        @test nr1.cost == cost
        @test nr1.x == x_dict
        @test nr1.simplex_iters == simplex_iters
        @test nr1.depth == depth
        @test nr1.int_infeas == int_infeas
        @test_throws ErrorException Cerberus.get_basis(nr1)
        @test_throws ErrorException Cerberus.get_model(nr1)
    end

    let nr2 = @inferred Cerberus.NodeResult(
            cost,
            x_dict,
            simplex_iters,
            depth,
            int_infeas,
            Cerberus.IncrementalData(Cerberus.WARM_START),
        )
        basis = Cerberus.Basis(
            _VI(1) => MOI.BASIC,
            _VI(2) => MOI.BASIC,
            _CI{_SAF,_GT}(1) => MOI.NONBASIC,
            _CI{_SAF,_LT}(2) => MOI.NONBASIC,
            _CI{_SAF,_LT}(3) => MOI.NONBASIC,
        )
        nr2.incremental_data._basis = basis
        @test nr2.cost == cost
        @test nr2.x == x_dict
        @test nr2.simplex_iters == simplex_iters
        @test nr2.depth == depth
        @test nr2.int_infeas == int_infeas
        @test Cerberus.get_basis(nr2) === basis
        @test_throws ErrorException Cerberus.get_model(nr2)
    end

    @testset "reset!" begin
        cost = 5.6
        x = Dict(_VI(1) => 15.7)
        si = 12
        dp = 5
        ii = 2
        basis = Dict{Any,MOI.BasisStatusCode}(_CI{_SV,_IN}(1) => MOI.BASIC)
        model = Gurobi.Optimizer()
        nr = Cerberus.NodeResult(cost, x, si, dp, ii, Cerberus.IncrementalData(Cerberus.HOT_START))
        nr.incremental_data._basis = basis
        Cerberus.set_model!(nr, model)
        @test nr.cost == cost
        @test nr.x == x
        @test nr.simplex_iters == si
        @test nr.depth == dp
        @test nr.int_infeas == ii
        @test Cerberus.get_basis(nr) === basis
        @test Cerberus.get_model(nr) === model
        Cerberus.reset!(nr)
        @test isnan(nr.cost)
        @test nr.simplex_iters == 0
        @test nr.depth == 0
        @test nr.int_infeas == 0
        @test length(nr.x) == 1
        @test all(isnan, values(nr.x))
        @test all(isnan, Cerberus.get_basis(nr))
        @test Cerberus.get_model(nr) === nothing
    end
end

@testset "CurrentState" begin
    fm = _build_dmip_formulation()

    nvars = 2
    pb_float = 12.4
    pb_int = 12

    cs1 = @inferred _CurrentState(nvars, CONFIG)
    cs2 = @inferred _CurrentState(nvars, CONFIG, primal_bound = pb_float)
    cs3 = @inferred _CurrentState(nvars, CONFIG, primal_bound = pb_int)

    @test length(cs1.tree) == 1
    @test length(cs2.tree) == 1
    @test length(cs3.tree) == 1

    @test _is_root_node(Cerberus.pop_node!(cs1.tree))
    @test _is_root_node(Cerberus.pop_node!(cs2.tree))
    @test _is_root_node(Cerberus.pop_node!(cs3.tree))

    @test cs1.primal_bound == Inf
    @test cs2.primal_bound == pb_float
    @test cs3.primal_bound == pb_int

    @test cs1.dual_bound == -Inf
    @test cs2.dual_bound == -Inf
    @test cs3.dual_bound == -Inf

    @test length(cs1.best_solution) == nvars
    @test length(cs2.best_solution) == nvars
    @test length(cs3.best_solution) == nvars
    @test all(isnan, values(cs1.best_solution))
    @test all(isnan, values(cs2.best_solution))
    @test all(isnan, values(cs3.best_solution))

    @test cs1.total_node_count == 0
    @test cs2.total_node_count == 0
    @test cs3.total_node_count == 0

    @test cs1.total_simplex_iters == 0
    @test cs2.total_simplex_iters == 0
    @test cs3.total_simplex_iters == 0
end
