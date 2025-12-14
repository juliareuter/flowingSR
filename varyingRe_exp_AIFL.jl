
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
# read arguments from the command line (mainly required for experiments with multiple parameter configs)
# ==================================================================================================
# function parse_commandline()
#     s = ArgParseSettings()
#     @add_arg_table s begin
#         "vf"
#             arg_type = String
#         "Re"
#             arg_type = Int
#         "run"
#             arg_type = Int
#     end

#     return parse_args(s)
# end

# parsed_args = parse_commandline()
# vf = parsed_args["vf"]
# Re = parsed_args["Re"]
# run = parsed_args["run"]

# ==================================================================================================
# If you want to start the script without handing over parameters for vf, Re and run:
# Comment the above lines and uncomment the following three lines
# ==================================================================================================
vf = "00"
Re = 50
run = 0

# ==================================================================================================
# Define experiment name and path to dataset folder
# ==================================================================================================

exp_name = "AIFL_exp_final"
dataset_prefix = "./GP_data_varying_Re/varying_Re_all_n30_hidden30_dropout_AIFL" #insert your own path here
#dataset_prefix = "/Users/juliareu/GitCode/flowingSR/GP_data_varying_Re/varying_Re_all_n30_hidden30_dropout_AIFL" 


# set vf to "00" for experiments where vf is a variable in the dataset and Re is fixed 
if vf == "00"                             
    arbitrary_name = "Re$(Re)_shuffled" 
else
    arbitrary_name = "vf$(vf)_shuffled"
end

# ==================================================================================================
# data preparation
# ==================================================================================================

data_matrix = Matrix(CSV.read("$(dataset_prefix)/$(arbitrary_name).csv", DataFrame))
if vf == "00"
    data_matrix = data_matrix[:, [1,2,3,4,11]]
else
    data_matrix = data_matrix[:, [1,2,3,5,11]]
end

train_part = size(data_matrix,1)
train_configs = round(train_part/30 * 0.8) # 80 percent of data is for training
parts_1 = train_configs*30 / train_part 
parts_2 = 1 - parts_1
parts = [parts_1, parts_2]

# ==================================================================================================
# define the units in the following way: [units of input feates, unit of output feature, u"0"] (always add u"0" after the output unit)
# ==================================================================================================

units = [u"m",  u"0", u"0", u"0", u"0", u"0"]

# add run to arbitrary_name
arbitrary_name = "$(arbitrary_name)_run$(run)"

# ==================================================================================================
# these are the objectives considered during evolution, i.e., while the program is creating new equations:
# f1: MSE,
# f2: Spearman correlation (to keep promising individuals with high correlation but low accuracy in the population),
# f3: dimension penalty (see file dim_analysis.jl in TiSR),
# f4: complexity
# ==================================================================================================

selection_objectives = [:ms_processed_e, :minus_spearman, :dim_penalty, :custom_compl] 

# ==================================================================================================
# in hall of fame (final Pareto-optimal front), no correlation is considered, to only store equations that are already good
# ==================================================================================================

hall_of_fame_objectives = [:ms_processed_e, :dim_penalty, :custom_compl]

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
        n_gens                  = 200,              # either define number of generations, or a time limit (t_lim, for example t_lim = 60.0 * 300 for 5 hours)
        pop_size                = 500,
        max_compl               = 30,
        pow_abs_param           = true,
        prevent_doubles         = 1e-7,
        t_lim                   = typemax(Float64),
        multithreadding         = true,
        death_penalty_dims      = false,            # set this to true, if you want to exclude all equations with unit violations during the search. then also remove the "dim_penalty" objective above
        always_drastic_simplify = false,
    ),
    selection=selection_params(
        hall_of_fame_objectives           = hall_of_fame_objectives,          # -> objectives for the hall_of_fame
        selection_objectives              = selection_objectives              # -> objectives for the Pareto-optimal selection part of selection
    ),
    fitting=fitting_params(
        early_stop_iter = 5,
        max_iter        = 30,
        pre_residual_processing = nothing, # to evaluate on the sum over 30 particles directly on the true drag force (not the GNN output), replace "nothing" here with: (x, ind) -> [sum(x[i:i+29]) for i in 1:30:length(x)-1]
        ),

        binops          = (  +,   -,   *,   /,  ^),  # -> binary function set to choose from
        p_binops        = (1.0, 1.0, 1.0, 1.0, 1.0),  # -> probabilites for selection of each binary functions (same length as provided binops) (dont need to add up to 1, adjusted accordingly)
        unaops          = (exp, log, sin, cos, abs, sqrt_abs, pow2, pow3),  # -> unary function set to choose from
        p_unaops        = (1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0),  # -> probability for each unary function
        illegal_dict = Dict(:sin => (sin, cos), # -> definition of illegal nestings, such as avoiding sin(cos(x))..
                        :cos => (sin, cos),
                        :abs => (abs,),
                        :exp => (exp, sqrt_abs), #log
                        :log => (log,), #exp
                        :pow2 => (log, sqrt_abs),
                        :sqrt_abs => (sqrt_abs,),
                        :pow3 => (pow3, pow2),
                        :^ => (^,),),

    mutation=mutation_params(;
        p_crossover        = 4.0,
        p_point            = 1.0,
        p_innergrow        = 0.0,
        p_insert           = 0.2,
        p_hoist            = 0.2,
        p_subtree          = 0.2,
        p_add_term         = 0.1,
        p_simplify         = 1.0,
        p_drastic_simplify = 1.0,),
);

# ==================================================================================================
# main generational loop
# ==================================================================================================
#check if output file already exists
if !isfile("$(exp_name)/$(arbitrary_name)/$(arbitrary_name)_hall_of_fame.csv")
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
    # write pareto optimal ones to csv file
    # ==================================================================================================
    write_to_csv(hall_of_fame, population, prog_dict, ops, exp_name = exp_name)
else
    println("$(arbitrary_name).csv already exists, skipping run")
end


