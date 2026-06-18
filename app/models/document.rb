class Document < ApplicationRecord
  DOCUMENT_TYPES = %w[insurance registration maintenance_record receipt marina_contract photo other].freeze

  belongs_to :account
  belongs_to :asset, optional: true
  has_one_attached :file

  validates :title, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 2_000 }
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validate :asset_belongs_to_account

  private

  def asset_belongs_to_account
    return if asset.blank? || account_id.blank? || asset.account_id == account_id

    errors.add(:asset, "must belong to the selected owner")
  end
end
