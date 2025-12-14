
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
        "phi"
            arg_type = String
            help = "options are: 0.05, 0.1, 0.2, 0.3, 0.4"  
        "run"
            arg_type = Int
    end

    return parse_args(s)
end

# ==================================================================================================
parsed_args = parse_commandline()
phi = parsed_args["phi"]
run = parsed_args["run"]

exp_name = "finalStokes"

dataset_prefix = "./data/thirtyParticles"

arbitrary_name = "Re0_phi$(phi)_n30_symmetricRotation_dimensionless"


data_matrix = Matrix(CSV.read("$(dataset_prefix)/$(arbitrary_name).csv", DataFrame))
data_matrix = data_matrix[:, [1,2,3,7]]
units = [u"m",  u"0", u"0", u"N", u"0"]

#add run to arbitrary_name
arbitrary_name = "$(arbitrary_name)_run$(run)"

time = 60 * 120.0

always_correct_dims = false
p_correct_dims = 0.0
death_penalty_dims = false
hall_of_fame_objectives = [:ms_processed_e, :dim_penalty, :custom_compl]
selection_objectives = [:ms_processed_e, :minus_spearman, :dim_penalty, :custom_compl]

# ==================================================================================================
# preparation
# ==================================================================================================

train_part = size(data_matrix,1)
train_configs = round(train_part/30 * 0.5)
parts_1 = train_configs*30 / train_part 
parts_2 = 1 - parts_1

parts = [parts_1, parts_2]

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
        n_gens                  = 150,
        pop_size                = 500,
        max_compl               = 35,
        pow_abs_param           = true,
        prevent_doubles         = 1e-7,
        t_lim                   = typemax(Float64),
        multithreadding         = true,
        always_correct_dims     = always_correct_dims,
        death_penalty_dims      = death_penalty_dims,
        always_drastic_simplify = false,
    ),
    selection=selection_params(
        hall_of_fame_objectives           = hall_of_fame_objectives,          # -> objectives for the hall_of_fame
        selection_objectives              = selection_objectives              # -> objectives for the Pareto-optimal selection part of selection
    ),
    fitting=fitting_params(
        early_stop_iter = 5,
        max_iter        = 30,
        pre_residual_processing = nothing,),

        binops          = (  +,   -,   *,   /,  ^),  # -> binary function set to choose from
        p_binops        = (1.0, 1.0, 1.0, 1.0, 1.0),  # -> probabilites for selection of each binary functions (same length as provided binops) (dont need to add up to 1, adjusted accordingly)
        unaops          = (exp, log, sin, cos, abs, sqrt_abs, pow2, pow3),  # -> unary function set to choose from
        p_unaops        = (1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0),  # -> probability for each unary function
        illegal_dict = Dict(:sin => (sin, cos),
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
    # write pareto optimal ones to excel
    # ==================================================================================================
    write_to_csv(hall_of_fame, population, prog_dict, ops, exp_name = exp_name)
else
    println("$(arbitrary_name).csv already exists, skipping run")
end


