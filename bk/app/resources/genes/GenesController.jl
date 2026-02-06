module GenesController

using Genie.Renderer.Html
using SearchLight
using Genie.Requests
using Genie.Renderer
using GenieSession 
using ..Genes
using ..Users

# --- CUSTOM AUTH HELPERS ---

# 1. Manually check if user is logged in
function get_logged_in_user()
  try
    sess = GenieSession.session(params())
    # We look for the standard GenieAuth key
    if haskey(sess.data, :__auth_user_id)
      user_id = sess.data[:__auth_user_id]
      return findone(User, id = user_id)
    end
  catch
    return nothing
  end
  # return nothing
end

# 2. Manual Gatekeeper
function is_logged_in()
  return get_logged_in_user() !== nothing
end

# --- CONTROLLER ACTIONS ---

function calculate_gc(sequence::String)
  if isempty(sequence)
    return 0.0
  end
  g_count = count(c -> c == 'G' || c == 'g', sequence)
  c_count = count(c -> c == 'C' || c == 'c', sequence)
  return round((g_count + c_count) / length(sequence) * 100, digits=2)
end

function dashboard()
  # FIX: Don't use GenieAuthentication.authenticated()
  # Use our manual check instead.
  user = get_logged_in_user()

  # if user === nothing
  #   println("Access Denied: No session found.")
  #   return redirect(:show_login)
  # end
  
  # println("Access Granted: Welcome $(user.username)")
  genes = all(Gene)
  
  # html(:genes, :dashboard, genes=genes, user=user)
  html(:genes, :dashboard, genes=genes)
end

function search()
  user = get_logged_in_user()

  if user === nothing
    return redirect(:show_login)
  end
  
  query = params(:q, "")
  results = find(Gene, SQLWhereExpression("functional_annotation LIKE ?", "%$(query)%"))
  
  # html(:genes, :dashboard, genes=results, user=user)
  html(:genes, :dashboard, genes=results)
end

end