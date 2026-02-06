import SearchLight.Migrations: create_table, column, primary_key, add_index, drop_table, add_foreign_key

function setup()
  # 1. Create GENES table (Genomics Research)
  create_table(:genes) do
    [
      primary_key()
      column(:locus_tag, :string, limit=50)
      column(:chromosome, :string, limit=10)
      column(:functional_annotation, :string)
      column(:sequence_data, :text)
    ]
  end
  add_index(:genes, :locus_tag)

  # 2. Create USERS table (Researcher Development/Supervision)
  create_table(:users) do
    [
      primary_key()
      column(:username, :string, limit=100)
      column(:password, :string, limit=100)
      column(:name, :string, limit=100)
      column(:role, :string, limit=20) # 'admin' (Fellow) or 'student' (Honours/HDR)
      column(:email, :string, limit=100)
    ]
  end
  add_index(:users, :username)
end

function setdown()
  drop_table(:genes)
  drop_table(:users)
end
