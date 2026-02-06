module AuthenticationController

using Genie.Renderer
using Genie.Renderer.Html
using SearchLight
using GenieSession 
using ..Users

# 1. Import the MODULES, not the functions
using Genie.Requests 

function show_login()
  html(:authentication, :login)
end

function login()
  # 2. Use FULLY QUALIFIED names to prevent errors
  username_input = Genie.Router.params(:username, "")
  password_input = Genie.Router.params(:password, "")
  
  println("Login attempt for: $username_input")

  user = findone(User, username = username_input, password = password_input)

  if user !== nothing
    println("User found. Initializing Session...")

    # 3. Create Session (Passing params explicitly)
    sess = GenieSession.session(Genie.Router.params())

    # 4. Set User ID & FORCE SAVE
    GenieSession.set!(sess, :__auth_user_id, user.id)
    # GenieSession.save(sess)
    
    println("Session saved. Redirecting to dashboard...")
    return Genie.Renderer.redirect(:dashboard)
  else
    println("Invalid credentials.")
    return Genie.Renderer.redirect(:show_login)
  end
end

function logout()
  try
    sess = GenieSession.session(Genie.Router.params())
    GenieSession.unset!(sess, :__auth_user_id)
    # GenieSession.save(sess)
  catch
    # Ignore errors if session is already gone
  end
  Genie.Renderer.redirect(:show_login)
end

end