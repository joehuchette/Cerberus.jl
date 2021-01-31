@testset "formulate!" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
end
