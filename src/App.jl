module App

using Genie
using SearchLight
using SearchLightSQLite
using Genie.Router
using Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests
using Random

# --- MANUAL SESSION MANAGER ---
module SimpleSession
    using Random
    
    # Store: SessionToken => UserID
    const SESSIONS = Dict{String, Any}()

    function create(user_id)
        token = randstring(32)
        SESSIONS[token] = user_id
        return token
    end

    # FIX: Removed '::String' type annotation to allow SubStrings
    function get_user(token)
        # Convert to String just to be safe for Dict lookup
        return get(SESSIONS, String(token), nothing)
    end

    # FIX: Removed '::String' type annotation
    function destroy(token)
        delete!(SESSIONS, String(token))
    end
end

# Configuration
Genie.config.run_as_server = true

# Load Resources
include(joinpath("..", "app", "resources", "users", "Users.jl"))
include(joinpath("..", "app", "resources", "genomics", "Genomics.jl"))

# Load Controllers
include(joinpath("..", "app", "controllers", "AuthController.jl"))
include(joinpath("..", "app", "controllers", "DashboardController.jl"))

# Load Routes
include(joinpath("..", "routes.jl"))

end
