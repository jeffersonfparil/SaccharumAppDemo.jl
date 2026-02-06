module AuthController
using Genie.Renderer.Html
using Genie.Requests
using Genie.Router
using HTTP 
using ..App.Users
using ..App.SimpleSession 

function login_page()
    html(:authentication, :login)
end

function login()
    username = postpayload(:username)
    password = postpayload(:password)
    
    println("🔍 Login attempt for: $username")
    
    user = Users.authenticate(username, password)
    
    if !isnothing(user)
        token = SimpleSession.create(user.id)
        println("✅ Auth successful. Token generated: $(token[1:5])...")
        
        # FIX: Simplest possible cookie string. No HttpOnly/SameSite to prevent browser rejection on localhost.
        cookie_val = "session_token=$(token); Path=/"
        
        headers = [
            "Location" => "/dashboard", 
            "Set-Cookie" => cookie_val
        ]
        return HTTP.Response(302, headers, "Redirecting...")
    else
        println("❌ Invalid credentials.")
        return redirect(:login_page)
    end
end

function logout()
    headers = [
        "Location" => "/login", 
        "Set-Cookie" => "session_token=deleted; Path=/; Max-Age=0"
    ]
    return HTTP.Response(302, headers, "Logging out...")
end
end
