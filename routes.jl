using Genie.Router
using .AuthController
using .DashboardController

route("/", AuthController.login_page, named=:login_page)
route("/login", AuthController.login, method=POST)
route("/logout", AuthController.logout)

route("/dashboard", DashboardController.index, named=:dashboard)

route("/api/data", DashboardController.api_genome_data)
route("/api/search", DashboardController.api_search)
route("/api/export_csv", DashboardController.export_csv)
