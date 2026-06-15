class BinderNote < ApplicationRecord
  NOTE_TYPES = %w[general maintenance owner_preference operational issue other].freeze

  belongs_to :account
  belongs_to :asset, optional: true

  validates :title, :body, presence: true
  validates :title, length: { maximum: 120 }
  validates :body, length: { maximum: 2_000 }
  validates :note_type, inclusion: { in: NOTE_TYPES }
end
