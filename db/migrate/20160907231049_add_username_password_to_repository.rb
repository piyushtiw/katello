class AddUsernamePasswordToRepository < ActiveRecord::Migration[4.2]
  def change
    add_column :katello_repositories, :upstream_username, :string, :limit => 255
    add_column :katello_repositories, :upstream_password, :string, :limit => 255
  end
end
