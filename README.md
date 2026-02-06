# SaccharumAppDemo.jl
Sugarcane Genomics App Demo using Genie.jl


```julia
using Pkg
using Dates
using UUIDs

# --- Helper to write files ---
function write_file(path, content)
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, content)
    end
    println("Created: \$path")
end


Pkg.add(["Genie", "GenieSession", "SearchLight", "SearchLightSQLite", "SQLite", "DataFrames", "CSV", "JSON", "MbedTLS", "Dates", "Logging", ])








```