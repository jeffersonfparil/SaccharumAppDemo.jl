using Genie.Router
using .App.AuthController
using .App.DashboardController
using .App.IGVController  # Ensure this is used

# --- Authentication ---
route("/", AuthController.login_page)
route("/login", AuthController.login, method=POST)
route("/logout", AuthController.logout)

# --- Dashboard ---
route("/dashboard", DashboardController.index)
route("/api/data", DashboardController.api_genome_data)
route("/api/search", DashboardController.api_search)
route("/api/export_csv", DashboardController.export_csv)

# --- IGV Browser (The Missing Link) ---
route("/igv", IGVController.index)
route("/api/igv/data.bed", IGVController.api_bed_data)
using .App.BrowsersController

route("/jbrowse", BrowsersController.jbrowse)
route("/gbrowse", BrowsersController.gbrowse)
