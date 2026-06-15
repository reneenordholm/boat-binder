class Account < ApplicationRecord
  ACCOUNT_TYPES = %w[internal client].freeze

  has_many :contacts, dependent: :destroy
  has_many :assets, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :binder_notes, dependent: :destroy

  validates :name, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
end
