class User < ApplicationRecord
  ROLES = %w[admin captain owner].freeze
  INVITATION_EXPIRES_IN = 7.days

  has_secure_password
  generates_token_for :invitation, expires_in: INVITATION_EXPIRES_IN do
    [ invitation_sent_at&.to_i, invitation_accepted_at&.to_i, active? ]
  end

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

  def invitation_pending?
    invitation_sent_at.present? && invitation_accepted_at.blank?
  end

  def invitation_accepted?
    invitation_accepted_at.present?
  end
end
