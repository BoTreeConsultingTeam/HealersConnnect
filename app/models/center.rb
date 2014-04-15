class Center < ActiveRecord::Base
  belongs_to :foundation
  has_many :user_roles
  attr_accessible :name, :address, :location, :lat, :long, :phone1, :phone2, :mobile, :email, :foundation_id
  validates_presence_of :name, :address, :email, :location

end
