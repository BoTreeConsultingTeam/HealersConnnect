class AddColumnStatusToCourses < ActiveRecord::Migration
  def change
    add_column :courses, :status, :boolean, default: true
  end
end
