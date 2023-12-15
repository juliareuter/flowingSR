
using CSV
using DataFrames
using SymbolicUtils
using Symbolics

pow_abs(v1, v2) = abs(v1)^v2
sqrt_abs(v1) = sqrt(abs(v1))
pow2(v1) = v1^2
pow3(v1) = v1^3
@variables v1 v2 v3 v4 v5

function simplify_equation(eq)
    eq = replace(eq, "--" => "+")
    eq_simp = eval(Meta.parse(eq))
    simplify(eq_simp)
    repr(eq_simp)
end   

thresh_wo_noise = [1.0e-23, 1.0e-25, 1.0e24, 1000, 1.0e-27, 1.0e-21, 1.0e-21, 1.0e-22, 1.0e-25]
thresh_original = [36000, 350, 1.0e52, 1000, 0.04, 0.04, 0.00005, 310000, 2.5e-15]

has_original_measures = [1,2,5,7] #original datasets available

dataset = 1:9
run = 0:10
algo = ["f1f2f3_obj_penalty", "f1f2f4_baseline", "f1f2f4_correct_all", "f1f2f4_death_penalty", "f1f3f4_obj_penalty"]
dataset_type = ["original", "wo_noise"]
for ds in dataset
    println("Dataset: ",ds)
    valid_eqs = String[]
    for dst in dataset_type
        if dst == "original"
            thresh = thresh_original[ds]
            if ds in has_original_measures
                dataset_appendix = "_original"
            else
                dataset_appendix = "_generated_noise"
            end
        elseif dst == "wo_noise"
            thresh = thresh_wo_noise[ds]
            dataset_appendix = "_generated_wo_noise"
        end
        for al in algo
            columns = ["run", "eqs_orig_rounded", "ms_processed_e"]
            isfile("./analysis/$(ds)$(dataset_appendix)_$(al)_good.csv") ? res_good_df = CSV.read("./analysis/$(ds)$(dataset_appendix)_$(al)_good.csv", DataFrame) : res_good_df = DataFrame([name => [] for name in columns])
            isfile("./analysis/$(ds)$(dataset_appendix)_$(al)_bad.csv") ? res_bad_df = CSV.read("./analysis/$(ds)$(dataset_appendix)_$(al)_bad.csv", DataFrame) : res_bad_df = DataFrame([name => [] for name in columns])
            for r in run
                (r in res_good_df.run || r in res_bad_df.run) && continue

                dataset_prefix = "./data/empiricalBench"
                arbitrary_name = "$(ds)$(dataset_appendix)_$(al)_$(r)"
                df = CSV.read("./results/$(arbitrary_name)/$(arbitrary_name)_hall_of_fame.csv", DataFrame)
                print(arbitrary_name)
                df_filtered = df[df.ms_processed_e .< thresh,[:eqs_orig_rounded, :ms_processed_e]]
                transform!(df_filtered,:eqs_orig_rounded => ByRow(eqs_orig_rounded -> simplify_equation(eqs_orig_rounded)) => :eqs_orig_rounded)
                print("\n\n") 
                show(df_filtered, truncate = 1000, allcols = true)
                print("\n\n") 
                println("Is this equation correct? ")

                #check if equation is already in list of valid ones
                if simplify_equation(df_filtered[1, :eqs_orig_rounded]) in valid_eqs
                    println("Yes")
                    eq_simp = simplify_equation(df_filtered[1, :eqs_orig_rounded])
                    push!(res_good_df, [r, eq_simp, df_filtered[1, :ms_processed_e]])

                #ask for user input
                else
                    inp = readline() 
                    inp = parse(Int64, inp)  
                    if inp > 0
                        valid_eqs = [valid_eqs; df_filtered[inp, :eqs_orig_rounded]]
                        push!(res_good_df, [r, df_filtered[inp, :eqs_orig_rounded], df_filtered[inp, :ms_processed_e]])
                    else
                        #add run to not successful runs
                        push!(res_bad_df, [r, df_filtered[1, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                    end        
                end
                println("=================================================")
            end
            println(res_good_df)
            CSV.write("./analysis/$(ds)$(dataset_appendix)_$(al)_good.csv", res_good_df)
            CSV.write("./analysis/$(ds)$(dataset_appendix)_$(al)_bad.csv", res_bad_df)
        end
    end
end
# Calling rdeadline() function 
# name = readline() 
# if name == 1
#     print("true")
# else
#     print("false")
# end 