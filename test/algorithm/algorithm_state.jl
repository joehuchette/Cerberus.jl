@testset "NodeResult" begin
    cost = 5.6
    x = [1.2, 3.4]
    simplex_iters = 3
    depth = 12
    int_infeas = 4
    let nr1 = @inferred Cerberus.NodeResult(
            cost,
            x,
            simplex_iters,
            depth,
            int_infeas,
        )
        @test nr1.cost == cost
        @test nr1.x == x
        @test nr1.simplex_iters == simplex_iters
        @test nr1.depth == depth
        @test nr1.int_infeas == int_infeas
    end
end

@testset "CurrentState" begin
    fm = _build_dmip_formulation()

    nvars = Cerberus.num_variables(fm)
    pb_float = 12.4
    pb_int = 12

    cs1 = @inferred _CurrentState(fm)
    cs2 = @inferred _CurrentState(fm, primal_bound = pb_float)
    cs3 = @inferred _CurrentState(fm, primal_bound = pb_int)

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

@testset "copy(::Basis)" begin
    src = Cerberus.Basis(
        [MOI.NONBASIC_AT_LOWER, MOI.BASIC, MOI.NONBASIC_AT_LOWER],
        [MOI.BASIC],
        MOI.BasisStatusCode[],
        [MOI.NONBASIC],
        MOI.BasisStatusCode[],
        [MOI.NONBASIC_AT_UPPER],
    )
    dest = copy(src)
    @test src.base_var_constrs == dest.base_var_constrs
    @test src.base_lt_constrs == dest.base_lt_constrs
    @test src.base_gt_constrs == dest.base_gt_constrs
    @test src.base_et_constrs == dest.base_et_constrs
    @test src.branch_lt_constrs == dest.branch_lt_constrs
    @test src.branch_gt_constrs == dest.branch_gt_constrs
    empty!(src.base_var_constrs)
    empty!(src.base_lt_constrs)
    empty!(src.base_gt_constrs)
    empty!(src.base_et_constrs)
    empty!(src.branch_lt_constrs)
    empty!(src.branch_gt_constrs)
    @test dest.base_var_constrs ==
          [MOI.NONBASIC_AT_LOWER, MOI.BASIC, MOI.NONBASIC_AT_LOWER]
    @test dest.base_lt_constrs == [MOI.BASIC]
    @test isempty(dest.base_gt_constrs)
    @test dest.base_et_constrs == [MOI.NONBASIC]
    @test isempty(dest.branch_lt_constrs)
    @test dest.branch_gt_constrs == [MOI.NONBASIC_AT_UPPER]
end
