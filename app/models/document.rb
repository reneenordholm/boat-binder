class Document < ApplicationRecord
  DOCUMENT_TYPES = %w[insurance registration maintenance_record receipt marina_contract photo other].freeze

  belongs_to :account
  belongs_to :asset, optional: true
  has_one_attached :file

  validates :title, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 2_000 }
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
end
