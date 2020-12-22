@testset "optimize!" begin
    fm = _build_dmip_formulation()
    config = Cerberus.AlgorithmConfig(lp_solver_factory=_silent_gurobi_factory)
    result = @inferred Cerberus.optimize!(fm, config)
    @test result.primal_bound ≈ 0.1 / 2.1
    @test result.dual_bound ≈ 0.1 / 2.1
    @test length(result.best_solution) == 3
    @test result.best_solution[_VI(1)] ≈ 1.0
    @test result.best_solution[_VI(2)] ≈ 2 / 2.1
    @test result.best_solution[_VI(3)] ≈ 0.0
    @test result.termination_status == Cerberus.OPTIMAL
    @test result.total_node_count == 3
    @test result.total_simplex_iters == 0
end

@testset "process_node" begin
    # A feasible model
    let
        fm = _build_dmip_formulation()
        state = Cerberus.CurrentState()
        node = Cerberus.Node()
        config = Cerberus.AlgorithmConfig(lp_solver_factory=_silent_gurobi_factory)
        result = @inferred Cerberus.process_node(fm, state, node, config)
        @test result.cost ≈ 0.5 - 2.5 / 2.1
        @test result.simplex_iters == 0
        @test length(result.x) == 3
        @test result.x[_VI(1)] ≈ 0.5
        @test result.x[_VI(2)] ≈ 2.5 / 2.1
        @test result.x[_VI(3)] ≈ 0.0
        @test result.basis == Cerberus.Basis(
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(1) => MOI.NONBASIC_AT_LOWER,
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(2) => MOI.BASIC,
            MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(3) => MOI.NONBASIC_AT_LOWER,
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.EqualTo{Float64}}(2) => MOI.NONBASIC,
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(3) => MOI.BASIC,
        )
        @test result.model === nothing
    end

    # An infeasible model
    let
        fm = _build_dmip_formulation()
        state = Cerberus.CurrentState()
        # A bit hacky, but force infeasibility by branching both up and down.
        node = Cerberus.Node([_VI(1)], [_VI(1)])
        config = Cerberus.AlgorithmConfig(lp_solver_factory=_silent_gurobi_factory)
        result = @inferred Cerberus.process_node(fm, state, node, config)
        @test result.cost == Inf
        @test result.simplex_iters == 0
        @test isempty(result.x)
        @test result.basis === nothing
        @test result.model === nothing
    end
end

@testset "_ip_feasible" begin
    fm = _build_dmip_formulation()
    config = Cerberus.AlgorithmConfig()
    x_int = Dict(_VI(1) => 1.0, _VI(2) => 3.2, _VI(3) => 0.0)
    @test Cerberus._ip_feasible(fm, x_int, config)
    x_int_2 = Dict(
        _VI(1) => 1.0 - 0.9config.int_tol,
        _VI(2) => 3.2,
        _VI(3) => 0.0 + 0.9config.int_tol,
    )
    @test Cerberus._ip_feasible(fm, x_int_2, config)
    x_int_3 = Dict(
        _VI(1) => 1.0 - 2config.int_tol,
        _VI(2) => 3.2,
        _VI(3) => 0.0 + config.int_tol,
    )
    @test !Cerberus._ip_feasible(fm, x_int_3, config)
end

@testset "_attach_parent_info!" begin
    fc = Cerberus.Node(_VI[], [_VI(1)])
    oc = Cerberus.Node([_VI(1)], _VI[])
    basis = Cerberus.Basis(_VI(1) => MOI.BASIC)
    model = Gurobi.Optimizer()
    result = Cerberus.NodeResult(
        12.3,
        1492,
        [1.2, 2.3, 3.4],
        basis,
        model,
    )
    @inferred Cerberus._attach_parent_info!(fc, oc, result)
    @test fc.parent_info == Cerberus.ParentInfo(12.3, basis, model)
    @test oc.parent_info == Cerberus.ParentInfo(12.3, basis, nothing)
end

@testset "update_state!" begin
    fm = _build_dmip_formulation()
    config = Cerberus.AlgorithmConfig()
    starting_pb = 12.3
    simplex_iters_per = 18
    cs = Cerberus.CurrentState(starting_pb)
    @test _is_root_node(Cerberus.pop_node!(cs.tree))
    node = Cerberus.Node()

    # 1. Prune by infeasibility
    nr1 = Cerberus.NodeResult(Inf, simplex_iters_per)
    @inferred Cerberus.update_state!(cs, fm, node, nr1, config)
    @test isempty(cs.tree)
    @test cs.total_node_count == 1
    @test cs.primal_bound == starting_pb
    @test cs.dual_bound == -Inf
    @test isempty(cs.best_solution)
    @test cs.total_simplex_iters == simplex_iters_per

    # 2. Prune by bound
    frac_soln = [0.2, 3.4, 0.6]
    frac_soln_dict = Dict(_VI(i) => frac_soln[i] for i in 1:3)
    nr2 = Cerberus.NodeResult(13.5, simplex_iters_per, frac_soln)
    @inferred Cerberus.update_state!(cs, fm, node, nr2, config)
    @test isempty(cs.tree)
    @test cs.total_node_count == 2
    @test cs.primal_bound == starting_pb
    @test cs.dual_bound == -Inf
    @test isempty(cs.best_solution)
    @test cs.total_simplex_iters == 2 * simplex_iters_per

    # 3. Prune by integrality
    int_soln = [1.0, 3.4, 0.0]
    int_soln_dict = Dict(_VI(i) => int_soln[i] for i in 1:3)
    new_pb = 11.1
    nr3 = Cerberus.NodeResult(new_pb, simplex_iters_per, int_soln)
    @inferred Cerberus.update_state!(cs, fm, node, nr3, config)
    @test isempty(cs.tree)
    @test cs.total_node_count == 3
    @test cs.primal_bound == new_pb
    @test cs.dual_bound == -Inf
    @test cs.best_solution == int_soln_dict
    @test cs.total_simplex_iters == 3 * simplex_iters_per

    # 4. Branch
    frac_soln_2 = [0.0, 2.9, 0.6]
    frac_soln_dict = Dict(_VI(i) => frac_soln_2[i] for i in 1:3)
    db = 10.1
    nr4 = Cerberus.NodeResult(db, simplex_iters_per, frac_soln)
    @inferred Cerberus.update_state!(cs, fm, node, nr4, config)
    @test Cerberus.num_open_nodes(cs.tree) == 2
    @test cs.total_node_count == 4
    @test cs.primal_bound == new_pb
    @test cs.dual_bound == -Inf
    @test cs.best_solution == int_soln_dict
    @test cs.total_simplex_iters == 4 * simplex_iters_per
    @inferred Cerberus.update_dual_bound!(cs)
    @test cs.dual_bound == db
    fc = Cerberus.pop_node!(cs.tree)
    @test isempty(fc.vars_branched_to_zero)
    @test fc.vars_branched_to_one == [_VI(3)]
    @test fc.parent_info == Cerberus.ParentInfo(10.1, nothing, nothing)
    oc = Cerberus.pop_node!(cs.tree)
    @test oc.vars_branched_to_zero == [_VI(3)]
    @test isempty(oc.vars_branched_to_one)
    @test oc.parent_info == Cerberus.ParentInfo(10.1, nothing, nothing)
end
