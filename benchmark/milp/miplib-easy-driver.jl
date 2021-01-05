using Cerberus, Gurobi, GZip, Justitia, MathOptInterface
const MOI = MathOptInterface

using Cerberus, Gurobi, Justitia

const INSTANCES = Dict(
    name => Justitia.MIPLIBInstance(name)
    for
    name in [
        "30n20b8",
        "50v-10",
        "academictimetablessmall",
        "air05",
        "app1-1",
        "app1-2",
        "assign1-5-8",
        "atlanta-ip",
        "b1c1s1",
        "beasleyC3",
        "binkar10_1",
        "blp-ar98",
        "blp-ic98",
        "bnatt400",
        "bppc4-08",
        "brazil3",
        "buildingenergy",
    ]
)

const TIME_LIMIT_SEC = 60.0

const APPROACHES = Dict(
    "cerberus-no-ws" => Justitia.MOIBasedApproach{Cerberus.Optimizer}(
        () -> begin
    model = Cerberus.Optimizer(Cerberus.AlgorithmConfig(incrementalism = Cerberus.WARM_START))
    MOI.set(model, MOI.TimeLimitSec(), TIME_LIMIT_SEC)
    return model
end,
    ),
    "cerberus-ws" => Justitia.MOIBasedApproach{Cerberus.Optimizer}(
        () -> begin
    model = Cerberus.Optimizer()
    MOI.set(model, MOI.TimeLimitSec(), TIME_LIMIT_SEC)
    return model
end,
    ),
    "cerberus-hs" => Justitia.MOIBasedApproach{Cerberus.Optimizer}(
        () -> begin
    model = Cerberus.Optimizer(Cerberus.AlgorithmConfig(incrementalism = Cerberus.HOT_START))
    MOI.set(model, MOI.TimeLimitSec(), TIME_LIMIT_SEC)
    return model
end,
    ),
    "gurobi" => Justitia.MOIBasedApproach{Gurobi.Optimizer}(
        () -> begin
    model = Gurobi.Optimizer()
    MOI.set(model, MOI.TimeLimitSec(), TIME_LIMIT_SEC)
    return model
end,
    ),
)

result_table = Justitia.CSVRecord("results.csv", Justitia.MILPResult)
Justitia.run_experiments!(
    result_table,
    INSTANCES,
    APPROACHES,
    Justitia.MILPResult,
)
