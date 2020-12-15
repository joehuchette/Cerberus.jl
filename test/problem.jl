@testset "Polyhedron" begin
    # Works with dense constraint matrix
    A_dense = [ 1.0 2.0 3.0
               -3.5 1.2 0.0]
    b = [3.0, 4.0]
    senses = [Cerberus.EQUAL_TO, Cerberus.LESS_THAN]
    l = [-1.0, -Inf, -Inf]
    u = [1.0, 2.0, Inf]
    p_dense = @inferred Cerberus.Polyhedron(A_dense, b, senses, l, u)
    @test p_dense.A == A_dense
    @test p_dense.b == b
    @test p_dense.senses == senses
    @test p_dense.l == l
    @test p_dense.u == u
    @test size(p_dense) == (2, 3)
    @test Cerberus._ambient_dim(p_dense) == 3
    # Works with sparse constraint matrix
    A_sparse = sparse(A_dense)
    p_sparse = @inferred Cerberus.Polyhedron(A_sparse, b, senses, l, u)
    @test p_sparse.A == A_sparse
    @test p_sparse.b == b
    @test p_sparse.senses == senses
    @test p_sparse.l == l
    @test p_sparse.u == u
    @test size(p_sparse) == (2, 3)
    @test Cerberus._ambient_dim(p_sparse) == 3

    # Throws on incompatible dimensions
    b_bad = [1.0]
    senses_bad = [Cerberus.EQUAL_TO, Cerberus.LESS_THAN, Cerberus.GREATER_THAN]
    l_bad = l[1:2]
    u_bad = vcat(u, -4.5)
    @test_throws AssertionError Cerberus.Polyhedron(A_dense, b_bad, senses, l, u)
    @test_throws AssertionError Cerberus.Polyhedron(A_dense, b, senses_bad, l, u)
    @test_throws AssertionError Cerberus.Polyhedron(A_dense, b, senses, l_bad, u)
    @test_throws AssertionError Cerberus.Polyhedron(A_dense, b, senses, l, u_bad)
end

@testset "Disjunction" begin
    A = sparse([ 1.0 2.0 3.0
                -3.5 1.2 0.0])
    b = [3.0, 4.0]
    senses = [Cerberus.EQUAL_TO, Cerberus.LESS_THAN]
    l = [-1.0, -Inf, -Inf]
    u = [1.0, 2.0, Inf]

    p1 = Cerberus.Polyhedron(A,  b, senses, l, u)
    p2 = Cerberus.Polyhedron(A, -b, senses, l, u)

    disjunction = @inferred Cerberus.Disjunction([p1, p2])
    @test length(disjunction.disjuncts) == 2
    @test disjunction.disjuncts[1] == p1
    @test disjunction.disjuncts[2] == p2

    # Ambient dimension 2, as opposed to 3 for p1 and p2
    A_bad = sparse([ 1.0 2.0
                    -3.5 1.2])
    l_bad = l[1:2]
    u_bad = u[1:2]
    p3 = Cerberus.Polyhedron(A_bad, b, senses, l_bad, u_bad)
    @test_throws AssertionError Cerberus.Disjunction([p1, p2, p3])
end

@testset "Formulation" begin
    A = sparse([ 1.0 2.0 3.0
                -3.5 1.2 0.0])
    b = [3.0, 4.0]
    senses = [Cerberus.EQUAL_TO, Cerberus.LESS_THAN]
    l = [-1.0, -Inf, -Inf]
    u = [1.0, 2.0, Inf]
    p = Cerberus.Polyhedron(A, b, senses, l, u)
    c = [1.0, -1.0, 0.0]
    integrality = [true, false, true]

    fm = @inferred Cerberus.Formulation(p, c, integrality)
    @test fm.poly == p
    @test fm.c == c
    @test fm.integrality == integrality
    @test Cerberus.num_constraints(fm) == 2
    @test Cerberus.num_variables(fm) == 3
    @test Cerberus.integral_indices(fm) == [1, 3]

    c_bad = c[1:2]
    integrality_bad = vcat(integrality, false)
    @test_throws AssertionError Cerberus.Formulation(p, c_bad, integrality)
    @test_throws AssertionError Cerberus.Formulation(p, c, integrality_bad)
end

@testset "Problem" begin
    A = sparse([ 1.0 2.0 3.0
                -3.5 1.2 0.0])
    b = [3.0, 4.0]
    senses = [Cerberus.EQUAL_TO, Cerberus.LESS_THAN]
    l = [-1.0, -Inf, -Inf]
    u = [1.0, 2.0, Inf]
    p = Cerberus.Polyhedron(A, b, senses, l, u)
    c = [1.0, -1.0, 0.0]
    integrality = [true, false, true]
    fm = Cerberus.Formulation(p, c, integrality)

    pr = @inferred Cerberus.Problem(fm, Cerberus.FormulationUpdater[])
    @test pr.base_form == fm
    @test Cerberus.num_constraints(pr) == 2
    @test Cerberus.num_variables(pr) == 3
end
