class User < ActiveRecord::Base
  has_one :user_profile
  has_many :workshops
  has_many :registrations
  has_many :certificates
  has_many :donations
  has_many :user_roles
  has_many :roles, through: :user_roles
  has_many :centers, through: :user_roles
  has_many :registration_donations

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable,
         authentication_keys: [:login]
  
  attr_accessible :email, :mobile, :password, :password_confirmation, :remember_me
  attr_accessible :login, :member_id
  
  validates_format_of       :email, with: Devise.email_regexp, allow_blank: true, :if => :email_changed?
  validates_presence_of     :password, on: :create
  validates_confirmation_of :password, :on=>:create
  validates_uniqueness_of :member_id, allow_blank: true

  class << self
    def create_from_user_profile!(user_profile)
      user = create!(email: user_profile.email, password: Settings.default_password, member_id: user_profile.member_id)
      user_profile.update_attribute(:user_id, user.id)
      user
    end
  end

  def is?(role)
   roles.find_by_alias(role.to_s).present?
  end

  def name
    user_profile.try(:name) || email
  end

  def is_foundation_admin?
    have_role?(Role::FOUNDATION_ADMIN)
  end

  def is_super_admin?
    have_role?(Role::SUPER_ADMIN)
  end

  def is_accountant?
    have_role?(Role::ACCOUNTANT)
  end

  def is_center_admin?
    have_role?(Role::CENTER_ADMIN)
  end
  
  def is_instructor?
    have_role?(Role::INSTRUCTOR)
  end

  def is_super_admin_or_foundation_admin?
    is_super_admin? || is_foundation_admin?
  end

  def have_role?(role_type)
    roles.pluck(:alias).include? role_type if roles
  end
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(['lower(member_id) = :value OR lower(email) = :value',
                               { value: login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def login=(login)
    @login = login
  end

  def login
    @login || mobile || email
  end

  def courses_attempted
    certificates.map(&:course)
  end

  def courses_workshop_map
    mapping = {}
    certificates.each do |certificate|
      mapping[certificate.course] = certificate.workshop
    end
    mapping
  end
end