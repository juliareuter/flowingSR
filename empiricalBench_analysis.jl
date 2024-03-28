using Revise
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
    eq_simp = PolyForm(eq_simp, recurse = true)
    simplify(eq_simp)
    repr(eq_simp)
end

thresh_wo_noise = [1.0e-23, 1.0e-25, 1.0e24, 1000, 1.0e-27, 0.03, 0.03, 1.0e-22, 1.0e-18, 10e70,10e70,10e70,10e70,10e70,10e70,10e70 ] #4:1e-30
thresh_original = repeat([10e70], 16)#36000, 350, 1.0e52, 1000, 0.25, 0.12, 0.05, 9.0e6, 9.0e-15] #4:1e-30
thresh_03noise = repeat([10e70], 16) #4:1e-30
thresh_05noise = repeat([10e70], 16) #4:1e-30

has_original_measures = [1,2,5,7] #original datasets available

dataset = [9]
run = 0:30
algo = ["f1f2f3f4_obj_penalty"]#["f1f2f3_obj_penalty", "f1f2f4_baseline", "f1f2f4_correct_all", "f1f2f4_death_penalty", "f1f3f4_obj_penalty"]
dataset_type = ["wo_noise", "001_noise", "003_noise"]#["wo_noise", "005_noise", "01_noise", "015_noise"] #["wo_noise", "original", "03noise", "05noise"]

exp_name = "allPPSNdatasets"

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
        elseif dst == "001_noise"
            dataset_appendix = "_generated_001noise"
            thresh = thresh_03noise[ds]
        elseif dst == "003_noise"
            dataset_appendix = "_generated_003noise"
            thresh = thresh_03noise[ds]
        elseif dst == "005_noise"
            dataset_appendix = "_generated_005noise"
            thresh = thresh_03noise[ds]
        elseif dst == "01_noise"
            dataset_appendix = "_generated_01noise"
            thresh = thresh_03noise[ds]
        elseif dst == "015_noise"
            dataset_appendix = "_generated_015noise"
            thresh = thresh_03noise[ds]

        elseif dst == "03noise"
            thresh = thresh_03noise[ds]
            dataset_appendix = "_generated_03noise"
        elseif dst == "05noise"
            thresh = thresh_05noise[ds]
            dataset_appendix = "_generated_05noise"
        end
        for al in algo
            columns = ["time_stamp", "run", "compl", "age", "dim_penalty", "minus_spearman", "mare", "mae",  "ms_processed_e", "eqs_orig_rounded"]
            isfile("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_good.csv") ? res_good_df = CSV.read("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_good.csv", DataFrame) : res_good_df = DataFrame([name => [] for name in columns])
            isfile("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_bad.csv") ? res_bad_df = CSV.read("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_bad.csv", DataFrame) : res_bad_df = DataFrame([name => [] for name in columns])
            isfile("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_close.csv") ? res_close_df = CSV.read("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_close.csv", DataFrame) : res_close_df = DataFrame([name => [] for name in columns])

            for r in run
                (r in res_good_df.run || r in res_bad_df.run || r in res_close_df.run) && continue

                arbitrary_name = "$(ds)$(dataset_appendix)_$(al)_$(r)"
                println(arbitrary_name)

                df = CSV.read("./results/$(exp_name)/$(arbitrary_name)/$(arbitrary_name)_hall_of_fame.csv", DataFrame)
                df[!,:run] .= r
                df_filtered = df[!,[:time_stamp, :run, :compl, :age, :dim_penalty, :minus_spearman, :mare, :mae, :ms_processed_e, :eqs_orig_rounded]]
                 #only select first 5 rows of df_filtered
                # try
                #     df_filtered = df_filtered[1:14,:]
                # catch
                #     df_filtered = df_filtered
                # end

                #= df_tmp = df_filtered[df_filtered.ms_processed_e .< thresh,[:time_stamp, :run, :compl, :age, :dim_penalty, :minus_spearman, :mare, :mae, :ms_processed_e, :eqs_orig_rounded]]
                if size(df_tmp,1) == 0
                    push!(res_bad_df, df_filtered[1,:])#, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                    continue
                else 
                    df_filtered = df_tmp
                end =#
                df_tmp = df_filtered[df_filtered.dim_penalty .== 0,[:time_stamp, :run, :compl, :age, :dim_penalty, :minus_spearman, :mare, :mae, :ms_processed_e, :eqs_orig_rounded]]
                if size(df_tmp,1) == 0
                    push!(res_bad_df, df_filtered[1,:])#, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                    continue
                else 
                    df_filtered = df_tmp
                end

                #= df_tmp = df_filtered[[occursin("log", x) for x in df_filtered.eqs_orig_rounded],[:time_stamp, :run, :compl, :age, :dim_penalty, :minus_spearman, :mare, :mae, :ms_processed_e, :eqs_orig_rounded]]
                if size(df_tmp,1) == 0
                    push!(res_bad_df, df_filtered[1,:])#, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                    continue
                else 
                    df_filtered = df_tmp
                end =#

                # df_tmp = df_filtered[[!occursin("exp", x) for x in df_filtered.eqs_orig_rounded],[:time_stamp, :run, :compl, :age, :dim_penalty, :minus_spearman, :mare, :mae, :ms_processed_e, :eqs_orig_rounded]]
                # if size(df_tmp,1) == 0
                #     push!(res_bad_df, df_filtered[1,:])#, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                #     continue
                # else 
                #     df_filtered = df_tmp
                # end

                # df_tmp = df_filtered[[occursin("sqrt", x) for x in df_filtered.eqs_orig_rounded],[:time_stamp, :run, :compl, :age, :dim_penalty, :minus_spearman, :mare, :mae, :ms_processed_e, :eqs_orig_rounded]]
                # if size(df_tmp,1) == 0
                #     push!(res_bad_df, df_filtered[1,:])#, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                #     continue
                # else 
                #     df_filtered = df_tmp
                # end


        

                #simplify equations
                try 
                    df_filtered = transform!(df_filtered,:eqs_orig_rounded => ByRow(eqs_orig_rounded -> simplify_equation(eqs_orig_rounded)) => :eqs_orig_rounded)
                catch
                    df_filtered = df_filtered
                end
                

                print("\n\n") 
                show(df_filtered[:, [:eqs_orig_rounded, :ms_processed_e, :time_stamp,]], truncate = 1000, allcols = true)
                print("\n\n") 
                println("Is this equation correct? ")
                eq_found = false
                #check if equation is already in list of valid ones
                for i in range(1, nrow(df_filtered))
                    if eq_found
                        continue
                    end
                    if df_filtered[i, :eqs_orig_rounded] in valid_eqs
                        println("Equation already verified as correct.")
                        println(i)
                        println(df_filtered[i, :eqs_orig_rounded])
                        print("\n\n") 
                        push!(res_good_df, df_filtered[i,:])#, :ms_processed_e]])
                        eq_found = true
                        continue
                    end
                end
                if eq_found
                    continue
                #ask for user input
                else
                    inp = readline() 
                    #if input contains "c"
                    if occursin("c", inp)
                        ind = parse(Int64, split(inp, "c")[2])
                        push!(res_close_df, df_filtered[ind,:])#, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                        continue
                    end
                    inp = parse(Int64, inp)  
                    if inp > 0
                        valid_eqs = [valid_eqs; df_filtered[inp, :eqs_orig_rounded]]
                        push!(res_good_df, df_filtered[inp,:])#, :eqs_orig_rounded], df_filtered[inp, :ms_processed_e]])
                    else
                        #add run to not successful runs
                        push!(res_bad_df, df_filtered[1,:])#, :eqs_orig_rounded], df_filtered[1, :ms_processed_e]])
                    end        
                end
                println("=================================================")
            end
            CSV.write("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_close.csv", res_close_df)
            CSV.write("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_good.csv", res_good_df)
            CSV.write("./analysis/$(exp_name)/$(ds)$(dataset_appendix)_$(al)_bad.csv", res_bad_df)
        end
    end
end
