module Users
using SearchLight, MbedTLS, Dates
export User

mutable struct User <: AbstractModel
    id::DbId
    username::String
    password_hash::String
    email::String
end

User() = User(DbId(), "", "", "")
SearchLight.table(::Type{User}) = "users"

function hash_password(password::String)
    return "hashed:" * bytes2hex(digest(MD_SHA256, password, "SugarSalt"))
end

function authenticate(username, password)
    u = findone(User, username = username)
    if isnothing(u)
        return nothing
    end
    return (u.password_hash == hash_password(password)) ? u : nothing
end
end
