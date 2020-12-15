function _build_problem()
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
    pr = Cerberus.Problem(fm, Cerberus.FormulationUpdater[])

    return pr
end
