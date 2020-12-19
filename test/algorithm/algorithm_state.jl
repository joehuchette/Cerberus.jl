function _isnan_vector(x::Vector{Float64}, len::Int)
    return all(isnan, x) && length(x) == len
end

@testset "NodeResult" begin
    x = [1.2, 3.4]
    cost = 5.6
    simplex_iters = 3
    nr1 = @inferred Cerberus.NodeResult(x, cost, nothing, simplex_iters)
    @test nr1.x == x
    @test nr1.cost == cost
    @test nr1.basis === nothing
    @test nr1.simplex_iters == simplex_iters

    basis = Cerberus.Basis(
        _VI(1) => MOI.BASIC,
        _VI(2) => MOI.BASIC,
        _CI(1) => MOI.NONBASIC,
        _CI(2) => MOI.NONBASIC,
        _CI(3) => MOI.NONBASIC,
    )
    nr2 = @inferred Cerberus.NodeResult(x, cost, basis, simplex_iters)
    @test nr2.x == x
    @test nr2.cost == cost
    @test nr2.basis == basis
    @test nr2.simplex_iters == simplex_iters

    simplex_iters_bad = -1
    @test_throws AssertionError Cerberus.NodeResult(x, cost, nothing, simplex_iters_bad)
end

@testset "CurrentState" begin
    fm = _build_dmip_formulation()

    pb_float = 12.4
    pb_int = 12

    cs1 = @inferred Cerberus.CurrentState(fm)
    cs2 = @inferred Cerberus.CurrentState(fm, pb_float)
    cs3 = @inferred Cerberus.CurrentState(fm, pb_int)

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

    @test _isnan_vector(cs1.best_solution, 3)
    @test _isnan_vector(cs2.best_solution, 3)
    @test _isnan_vector(cs3.best_solution, 3)

    @test cs1.total_simplex_iters == 0
    @test cs2.total_simplex_iters == 0
    @test cs3.total_simplex_iters == 0

    @testset "ip_feasible" begin
        fm = _build_dmip_formulation()
        config = Cerberus.AlgorithmConfig()
        @test !Cerberus.ip_feasible(fm, nothing, config)
        x_int = [1.0, 3.2, 0.0]
        @test Cerberus.ip_feasible(fm, x_int, config)
        x_int_2 = [1.0 - 0.9config.int_tol, 3.2, 0.0 + 0.9config.int_tol]
        @test Cerberus.ip_feasible(fm, x_int_2, config)
        x_int_3 = [1.0 - 2config.int_tol, 3.2, 0.0 + config.int_tol]
        @test !Cerberus.ip_feasible(fm, x_int_3, config)
    end

    @testset "update!" begin
        fm = _build_dmip_formulation()
        config = Cerberus.AlgorithmConfig()
        starting_pb = 12.3
        simplex_iters_per = 18
        cs = Cerberus.CurrentState(fm, starting_pb)
        node = Cerberus.Node()

        # 1. Prune by infeasibility
        nr1 = Cerberus.NodeResult(nothing, Inf, nothing, simplex_iters_per)
        @inferred Cerberus.update!(cs, fm, node, nr1, config)
        @test isempty(cs.tree)
        @test cs.enumerated_node_count == 1
        @test cs.primal_bound == starting_pb
        @test cs.dual_bound == -Inf
        @test _isnan_vector(cs.best_solution, 3)
        @test cs.total_simplex_iters == simplex_iters_per

        # 2. Prune by bound
        frac_soln = [0.2, 3.4, 0.6]
        nr2 = Cerberus.NodeResult(frac_soln, 13.5, nothing, simplex_iters_per)
        @inferred Cerberus.update!(cs, fm, node, nr2, config)
        @test isempty(cs.tree)
        @test cs.enumerated_node_count == 2
        @test cs.primal_bound == starting_pb
        @test cs.dual_bound == -Inf
        @test _isnan_vector(cs.best_solution, 3)
        @test cs.total_simplex_iters == 2 * simplex_iters_per

        # 3. Prune by integrality
        int_soln = [1.0, 3.4, 0.0]
        new_pb = 11.1
        nr3 = Cerberus.NodeResult(int_soln, new_pb, nothing, simplex_iters_per)
        @inferred Cerberus.update!(cs, fm, node, nr3, config)
        @test isempty(cs.tree)
        @test cs.enumerated_node_count == 3
        @test cs.primal_bound == new_pb
        @test cs.dual_bound == -Inf
        @test cs.best_solution == int_soln
        @test cs.total_simplex_iters == 3 * simplex_iters_per

        # 4. Branch
        frac_soln_2 = [0.0, 2.9, 0.6]
        db = 10.1
        nr4 = Cerberus.NodeResult(frac_soln, db, nothing, simplex_iters_per)
        @inferred Cerberus.update!(cs, fm, node, nr4, config)
        @test Cerberus.num_open_nodes(cs.tree) == 2
        # @test cs.tree
        @test cs.enumerated_node_count == 4
        @test cs.primal_bound == new_pb
        @test cs.dual_bound == -Inf
        @test cs.best_solution == int_soln
        @test cs.total_simplex_iters == 4 * simplex_iters_per

        @inferred Cerberus.update_dual_bound!(cs)
        @test cs.dual_bound == db
    end
end
