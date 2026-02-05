using Genie.Router
using Genie.Renderer
using Genie.Responses
using .GenesController, .AuthenticationController
using .Users, .Genes

route("/") do
  redirect(:dashboard)
end

route("/login", AuthenticationController.show_login, named = :show_login)
route("/login", AuthenticationController.login, method = POST)
route("/logout", AuthenticationController.logout)

route("/dashboard", GenesController.dashboard, named = :dashboard)
route("/search", GenesController.search)
