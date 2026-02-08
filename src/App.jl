module App

using Genie
using SearchLight
using SearchLightSQLite
using Genie.Router
using Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests
using Random
using HTTP

# --- SESSION MANAGER ---
module SimpleSession
    using Random
    const SESSIONS = Dict{String, Any}()
    function create(user_id)
        token = randstring(32)
        SESSIONS[token] = user_id
        return token
    end
    function get_user(token)
        return get(SESSIONS, String(token), nothing)
    end
    function destroy(token)
        delete!(SESSIONS, String(token))
    end
end

Genie.config.run_as_server = true

# Load Resources
include(joinpath("..", "app", "resources", "users", "Users.jl"))
include(joinpath("..", "app", "resources", "genomics", "Genomics.jl"))

# Load Controllers
include(joinpath("..", "app", "controllers", "AuthController.jl"))
include(joinpath("..", "app", "controllers", "DashboardController.jl"))
include(joinpath("..", "app", "controllers", "IGVController.jl"))
include(joinpath("..", "app", "controllers", "BrowsersController.jl")) # Added

# Load Routes
include(joinpath("..", "routes.jl"))

end
