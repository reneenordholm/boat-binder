class User < ApplicationRecord
  ROLES = %w[admin captain owner].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :service_visits, foreign_key: :performed_by_user_id, inverse_of: :performed_by_user, dependent: :restrict_with_exception

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  def email
    email_address
  end
end
