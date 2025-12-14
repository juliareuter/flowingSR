
using Plots
using Statistics
using CSV
using SymPy
using LinearAlgebra
using DataFrames

phi = ["0.05", "0.1", "0.15", "0.2", "0.25", "0.3", "0.35", "0.4", "all"]
r = symbols("r")
theta = symbols("theta")

# Function to plot the desired symbolic expression in a circle
function show_map(expr, filename)
    # Convert theta to radians
    theta_v = LinRange(0, 2π, 108)

    # The bounds of r/dp and its steps
    dr = 0.25    
    rmax = 5.0 + dr
    r_v = LinRange(1.0, rmax, round(Int, rmax / dr))

    # Create a meshgrid of r and theta values
    r_m, theta_m = meshgrid(r_v, theta_v)

    # Initialize a matrix to store the function values
    values = rand(Float64, size(theta_v, 1), size(r_v, 1))
    f_i_m = zeros(Float64, size(r_m))

    # Evaluate the function at each point on the meshgrid
    for i in 1:size(r_m, 1)
        for j in 1:size(r_m, 2)
            f_i_m[i, j] = expr.subs([r => r_m[i, j], theta => theta_m[i, j]])
        end
    end

    # Create a polar plot
    p = plot(
        theta_m, r_m, f_i_m, 
        levels = range(-0.9, 0.9, length = 101),
        color = :RdBu_r,
        aspect_ratio = :equal,
        framestyle = :none,
        legend = false,
        title = string(expr),
        size = (600, 600)
    )

    # Add a circle to the plot
    scatter!(p, [0], [0], markersize = 10, marker = :circle, color = :black)

    # Save the plot
    savefig(p, filename)
end

# Read the CSV file
affix_string = ["005"]
r = symbols("r")
theta = symbols("theta")

for affix in affix_string
    file_name = "./report_summaries/report_Re0_phi$affix.csv"
    println(file_name)
    test_read = CSV.read(file_name, DataFrame)

    count = 0
    for i in 1:size(test_read, 1)
        println(i)
        # Convert the expression to a SymPy expression
        expr = sympify(test_read[i, "eq"])

        # Check if the expression converges as r -> infinity
        try
            println("Trying to find a limit at r -> infinity")
            limit_value = simplify(expr.limit(r, Inf))
            println("Limit value = ", limit_value)
            if limit_value == 0.0
                println(i, ", ", expr, ", ", test_read[i, "r2"], " limit at r -> infinity is 0")
                count += 1
                fig_name = "figs/$file_name_replace('.csv','_')$count.png"
                # show_map(expr, fig_name)
            end
        catch
            println(i, ", ", expr, ", xxxxxxxx failed to find a limit at r -> infinity")
        end

        # Take the best 5 only
        if count == 2
            break
        end
    end
end


