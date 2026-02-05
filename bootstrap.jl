using Pkg
Pkg.activate(".")
using Genie, SearchLight, SearchLightSQLite
using GenieAuthentication
using GenieSession 
using GenieSessionFileSession

# Load Configuration
SearchLight.Configuration.load()

# Connect DB
if !isfile("db/sugarcane.sqlite")
    touch("db/sugarcane.sqlite")
end
SearchLight.connect()

# Load App
include("app/resources/users/Users.jl")
include("app/resources/authentication/AuthenticationController.jl")
include("app/resources/genes/Genes.jl")
include("app/resources/genes/GenesController.jl")
include("routes.jl")

Genie.up()
