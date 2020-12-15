function _build_formulation()
    A = sparse([ 1.0 2.0 3.0
                -3.5 1.2 0.0])
    b = [3.0, 4.0]
    senses = [Cerberus.EQUAL_TO, Cerberus.LESS_THAN]
    l = [-1.0, -Inf, -Inf]
    u = [1.0, 2.0, Inf]
    p = Cerberus.Polyhedron(A, b, senses, l, u)
    c = [1.0, -1.0, 0.0]
    integrality = [true, false, true]
    return Cerberus.Formulation(p, c, integrality)
end

function _build_problem()
    return Cerberus.Problem(_build_formulation, Cerberus.FormulationUpdater[])
end
