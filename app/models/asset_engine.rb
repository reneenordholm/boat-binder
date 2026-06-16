class AssetEngine < ApplicationRecord
  belongs_to :asset
  has_many :service_visit_engine_readings, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 2_000 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def display_name
    name.match?(/engine/i) ? name : "#{name} Engine"
  end
end
