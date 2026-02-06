module Users

using SearchLight, SearchLight.Validation, GenieAuthentication

export User

mutable struct User <: AbstractModel
  id::DbId
  username::String
  password::String
  name::String
  role::String
  email::String
end

User(; id=DbId(), username="", password="", name="", role="student", email="") = 
  User(id, username, password, name, role, email)

function SearchLight.Validation.validator(u::User)
  ValidationResult([
    ValidationRule(:username, User, presence=true),
    ValidationRule(:password, User, presence=true),
    ValidationRule(:role, User, in=["admin", "student"])
  ])
end

end
