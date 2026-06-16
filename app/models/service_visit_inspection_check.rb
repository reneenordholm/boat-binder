class ServiceVisitInspectionCheck < ApplicationRecord
  belongs_to :service_visit

  validates :label, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 2_000 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }
end
