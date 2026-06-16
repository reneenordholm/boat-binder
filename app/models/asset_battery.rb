class AssetBattery < ApplicationRecord
  belongs_to :asset
  has_many :service_visit_battery_checks, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :location, :battery_type, length: { maximum: 120 }
  validates :notes, length: { maximum: 2_000 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(active: :desc, name: :asc) }

  def status_label
    active? ? "Active" : "Inactive"
  end

  def status_tone
    active? ? :success : :neutral
  end
end
