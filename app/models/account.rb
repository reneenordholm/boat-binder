class Account < ApplicationRecord
  ACCOUNT_TYPES = %w[internal client].freeze

  has_many :contacts, dependent: :destroy
  has_many :assets, dependent: :destroy
  has_many :vessel_assets, -> { where(asset_type: "vessel", active: true).order(:name) }, class_name: "Asset"
  has_many :documents, dependent: :destroy
  has_many :binder_notes, dependent: :destroy

  validates :name, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :ordered, -> { order(:name) }

  def primary_contact
    contacts.find { |contact| contact.role.to_s.downcase.include?("owner") } || contacts.first
  end

  def status_label
    active? ? "Active" : "Inactive"
  end

  def status_tone
    active? ? :success : :neutral
  end
end
