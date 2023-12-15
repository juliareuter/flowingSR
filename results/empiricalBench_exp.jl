
# ==================================================================================================
# load TiSR module
# ==================================================================================================

using TiSR
using ArgParse
using DataFrames
using CSV
import DynamicQuantities: uparse,  @u_str
println(pathof(TiSR))


# ==================================================================================================
# read arguments from the command line 
# ==================================================================================================
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "dataset"
            arg_type = Int
            help = "options are: 1,2,3,4,5,6,7,8,9" #1: Hubble, 2: Kepler, 3: Newton, 4: Planck, 5: Leavitt, 6: Schechter, 7: Bode, 8: Ideal gas, 9: Rydberg
        "dataset_type"
            arg_type = String
            help = "options are: original, wo_noise"
        "obj"
            arg_type = String
            help = "options are: f1f2f4, f1f2f3, f1f3f4"
        "algo"
            help = "options are: correct_all, correct_mut, obj_penalty, death_penalty, baseline"
            arg_type = String   
        "run"
            arg_type = Int
    end

    return parse_args(s)
end

parsed_args = parse_commandline()
algo = parsed_args["algo"]
dataset = parsed_args["dataset"]
dataset_type = parsed_args["dataset_type"]
obj = parsed_args["obj"]
run = parsed_args["run"]

has_original_measures = [1,2,5,7] #original datasets available

if dataset_type == "original"
    if dataset in has_original_measures
        dataset_appendix = "_original"
    else
        dataset_appendix = "_generated_noise"
    end
elseif dataset_type == "wo_noise"
    dataset_appendix = "_generated_wo_noise"
end
dataset_prefix = "./data/empiricalBench"
arbitrary_name = "$(dataset)$(dataset_appendix)_$(obj)_$(algo)_$(run)"
#input units, target unit, dimensionless
if dataset == 1 #Hubble, stays as is
    data_matrix = Matrix(CSV.read("$dataset_prefix/hubble$dataset_appendix.csv", DataFrame))
    units = [u"m",  u"km * s^-1", u"0"] #use m instead of Mpc
elseif dataset == 2 #Kepler, stays as is
    data_matrix = Matrix(CSV.read("$dataset_prefix/kepler$dataset_appendix.csv", DataFrame))
    units = [u"m", u"day", u"0"] #use m instead of AU 
elseif dataset == 3 #Newton
    data_matrix = Matrix(CSV.read("$dataset_prefix/newton$dataset_appendix.csv", DataFrame))
    units = [u"m", u"kg", u"kg", u"N", u"0"]
elseif dataset == 4 #Planck, first try to remove scaling using exp(y), might change to log only later
    data_matrix = Matrix(CSV.read("$dataset_prefix/planck$(dataset_appendix)_scaled.csv", DataFrame)) #wo_infs
    #data_matrix[:, end] .= log.(data_matrix[:, end])
    units = [u"Hz", u"K", u"W * m^(-2) * Hz^(-1)", u"0"]
elseif dataset == 5 #Leavitt
    data_matrix = Matrix(CSV.read("$dataset_prefix/leavitt$dataset_appendix.csv", DataFrame))
    units = [u"0", u"0", u"0"]
elseif dataset == 6 #Schechter, uses log scale and log(x1), therefore unit of x1 is set to dimensionless
    data_matrix = Matrix(CSV.read("$dataset_prefix/schechter$dataset_appendix.csv", DataFrame))
    data_matrix[:, end] .= log.(data_matrix[:, end])
    units = [u"0", u"0", u"0"]
elseif dataset == 7 #Bode
    data_matrix = Matrix(CSV.read("$dataset_prefix/bode_original.csv", DataFrame))
    data_matrix[:, end] .= log.(data_matrix[:, end])
    units = [u"0", u"0", u"0"]
elseif dataset == 8 #Ideal gas, remove log scaling using exp(y)
    data_matrix = Matrix(CSV.read("$dataset_prefix/ideal_gas$dataset_appendix.csv", DataFrame))
    units = [u"mol", u"K", u"m^3", u"Pa", u"0"]
elseif dataset == 9 #Rydberg, uses log scale but input features are dimensionless, therefore stays as is
    data_matrix = Matrix(CSV.read("$dataset_prefix/rydberg$dataset_appendix.csv", DataFrame))
    units = [u"0", u"0", u"m", u"0"]
end

dataset == 4 ? time = 60 * 10.0 : time = 60 * 30.0

if algo == "correct_all"
    always_correct_dims = true
    p_correct_dims = 0.0
    death_penalty_dims = false
elseif algo == "correct_mut"
    always_correct_dims = false
    p_correct_dims = 4.0
    death_penalty_dims = true
elseif algo == "obj_penalty"
    always_correct_dims = false
    p_correct_dims = 0.0
    death_penalty_dims = false
elseif algo == "death_penalty"
    always_correct_dims = false
    p_correct_dims = 0.0
    death_penalty_dims = true
elseif algo == "baseline"
    always_correct_dims = false
    p_correct_dims = 0.0
    death_penalty_dims = false
end

if obj == "f1f2f3"
    hall_of_fame_objectives = [:ms_processed_e, :dim_penalty, :compl]
    selection_objectives = [:ms_processed_e, :minus_spearman, :dim_penalty]
elseif obj == "f1f2f4"
    hall_of_fame_objectives = [:ms_processed_e, :compl]
    selection_objectives = [:ms_processed_e, :minus_spearman, :compl]
elseif obj == "f1f3f4"
    hall_of_fame_objectives = [:ms_processed_e, :dim_penalty, :compl]
    selection_objectives = [:ms_processed_e, :dim_penalty, :compl]
end

# ==================================================================================================
# preparation
# ==================================================================================================
parts = [0.8, 0.2]

# ==================================================================================================
# options -> specify some custom settings, where the default setting is unsatisfactory
# ==================================================================================================
pow_abs(v1, v2) = abs(v1)^v2
sqrt_abs(v1) = sqrt(abs(v1))
pow2(v1) = v1^2
pow3(v1) = v1^3

ops, data = Options(
    data_descript=data_descript(
        data_matrix;
        arbitrary_name = arbitrary_name,
        parts          = parts,
       #fit_weights    = fit_weights, 
        units          = units,
    ),
    general=general_params(
        n_gens                  = typemax(Int64),
        pop_size                = 500,
        max_compl               = 30,
        pow_abs_param           = true,
        prevent_doubles         = 1e-7,
        t_lim                   = time, #make this 1 hour
        multithreadding         = true,
        always_correct_dims     = always_correct_dims,
        death_penalty_dims      = death_penalty_dims,
        always_drastic_simplify = true,
    ),
    selection=selection_params(
        hall_of_fame_objectives           = hall_of_fame_objectives,          # -> objectives for the hall_of_fame
        selection_objectives              = selection_objectives              # -> objectives for the Pareto-optimal selection part of selection
    ),
    fitting=fitting_params(
        early_stop_iter = 5,
        max_iter        = 30,),
        binops          = (  +,   -,   *,   /,  ^),  # -> binary function set to choose from
        p_binops        = (1.0, 1.0, 1.0, 1.0, 0.0),  # -> probabilites for selection of each binary functions (same length as provided binops) (dont need to add up to 1, adjusted accordingly)
        unaops          = (exp, log, sin, cos, abs, sqrt_abs, pow2, pow3),  # -> unary function set to choose from
        p_unaops        = (1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0),  # -> probability for each unary function
        illegal_dict = Dict(:sin => (sin, cos),
                        :cos => (sin, cos),
                        :abs => (abs,),
                        :exp => (exp, sqrt_abs), #log
                        :log => (log,), #exp
                        :pow2 => (log, sqrt_abs),
                        :sqrt_abs => (pow2, sqrt_abs),
                        :pow3 => (pow3, pow2),),

    mutation=mutation_params(;
        p_crossover        = 4.0,
        p_point            = 0.5,
        p_innergrow        = 0.0,
        p_insert           = 0.2,
        p_hoist            = 0.2,
        p_subtree          = 0.2,
        p_add_term         = 0.1,
        p_simplify         = 0.5,
        p_drastic_simplify = 0.5,
        p_correct_dims     = p_correct_dims,),
    
    
);

# ==================================================================================================
# main generational loop
# ==================================================================================================
#check if output file alrady exists
if !isfile("$(arbitrary_name)/$(arbitrary_name)_hall_of_fame.csv")
    hall_of_fame, population, prog_dict = generational_loop(data, ops);

# hall_of_fame, population, prog_dict = generational_loop(data, ops, start_pop=start_pop);

# hot start with previous population (age information is lost) # -----------------------------------
# start_pop = vcat(hall_of_fame["node"], population["node"])
# start_pop = vcat(hall_of_fame["eqs_trees"], population["eqs_trees"], start_pop)
# hall_of_fame, population, prog_dict = generational_loop(data, ops, start_pop = start_pop);

# Inspect the results # ---------------------------------------------------------------------------

col = "mare"
perm = sortperm(hall_of_fame[col])
hall_of_fame[col][perm]
hall_of_fame["compl"][perm]
hall_of_fame["node"][perm]#[1:5]

# show the Pareto front # --------------------------------------------------------------------------

#= using UnicodePlots

scatterplot(
    hall_of_fame["compl"],
    hall_of_fame["mare"],
    xlabel="complexity",
    ylabel="mean rel. dev."
) =#

# ==================================================================================================
# write pareto optimal ones to excel
# ==================================================================================================
write_to_csv(hall_of_fame, population, prog_dict, ops)
else
    println("$(arbitrary_name).csv already exists, skipping run")
end


