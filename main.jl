#using Revise
using TiSR
using JMcDM
using DataFrames
using CSV
using DynamicQuantities

println(pathof(TiSR))
dataset_name = "ideal_gas_generated_noise"
file_path = "./data/empiricalBench/$(dataset_name).csv"
#file_path = "./data/Re0_phi01_n30_symmetricRotation_dimensionless.csv"
df = CSV.read(file_path, DataFrame)
# reduce
maxes = maximum(Matrix(df), dims=1)
#df ./= maxes
# set variables for algorithm
data_matr = Matrix(df)
# create synthetic data
#data_matr = rand(1000, 3)
#data_matr[:, end] .= 3.0 .* (data_matr[:, 1] .* 5.0 .+ data_matr[:, 2]) .^ 7.0 + exp.(data_matr[:, 1] .* 5.0 .+ data_matr[:, 2])
# -> 3 * (v1 * 5 + v2)^7 + exp(v1 * 5 + v2)

# make some custom settings
#fit_weights = 1 ./ data_matr[:, end] # weights to minimize relative deviation
parts = [0.8, 0.2] #1: fitting, 2: early stop, all: evaluation of final front

pow_abs(v1, v2) = abs(v1)^v2
sqrt_abs(v1) = sqrt(abs(v1))

ops, data = Options(
    data_descript=data_descript(
        data_matr;
        parts          = parts,
        arbitrary_name = dataset_name,
        #fit_weights    = fit_weights
        units          = [u"0", u"m", u"0"],
    ),
    general=general_params(
        n_gens          = typemax(Int64),
        pop_size        = 500,
        max_compl       = 20,
        pow_abs_param   = true,
        prevent_doubles = 1e-3,
        prevent_doubles_across_islands = false,
        t_lim           = 60 * 5,                  # will run for 5 minutes
        multithreadding = true,
    ),
    selection=selection_params(
        hall_of_fame_objectives           = [:ms_processed_e, :mare, :compl],          # -> objectives for the hall_of_fame
        selection_objectives              = [:ms_processed_e, :compl, :minus_spearman]#, :age],           # -> objectives for the Pareto-optimal selection part of selection
    ),
    fitting=fitting_params(
        early_stop_iter = 5,
        max_iter        = 15,
    ),
    binops         = (  +,   -,   *,   /,  ^),  # -> binary function set to choose from
    p_binops       = (1.0, 1.0, 1.0, 1.0, 1.0),  # -> probabilites for selection of each binary functions (same length as provided binops) (dont need to add up to 1, adjusted accordingly)
    unaops         = (exp, log, sin, cos, abs),  # -> unary function set to choose from
    p_unaops       = (1.0, 1.0, 1.0, 1.0, 1.0),  # -> probability for each unary function
    illegal_dict = Dict(:sin => (sin, cos)  ,
                        :cos => (sin, cos)  ,
                        :abs => (abs,)      ,
                        :/ => (/,)          ,          
                        :log => (log,)      ,
                        :exp => (exp,)      ,)
);

# start the equation search
hall_of_fame, population, prog_dict = generational_loop(data, ops);

# inspect the results
col = "mse" # "mare" mean relative error
perm = sortperm(hall_of_fame[col])

hall_of_fame[col][perm]
hall_of_fame["compl"][perm]
hall_of_fame["node"][perm]

function choose_best_individual(hof::Dict{String, AbstractVector}; kwargs...)
    results = topsis(
        reduce(hcat, [hof[string(c)] for c in keys(kwargs)]),
        Float64[v for v in values(kwargs)],
        [minimum, minimum],
    ) 
    _, ind = findmax(results.scores)
    return hof["node"][ind]
end

write_to_csv(hall_of_fame, population, prog_dict, ops)
choose_best_individual(hall_of_fame, minus_r2=10.0, compl=0)