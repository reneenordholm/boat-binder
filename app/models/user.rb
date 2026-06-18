class User < ApplicationRecord
  ROLES = %w[admin captain owner].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :account_memberships, dependent: :destroy
  has_many :accounts, through: :account_memberships
  has_many :service_visits, foreign_key: :performed_by_user_id, inverse_of: :performed_by_user, dependent: :restrict_with_exception

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :name, length: { maximum: 120 }

  def email
    email_address
  end

  def admin?
    role == "admin"
  end

  def captain?
    role == "captain"
  end

  def owner?
    role == "owner"
  end

  def internal?
    admin? || captain?
  end

  def active_account_ids
    return Account.select(:id) if internal?

    account_memberships.active.select(:account_id)
  end
end
