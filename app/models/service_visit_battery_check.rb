class ServiceVisitBatteryCheck < ApplicationRecord
  belongs_to :service_visit
  belongs_to :asset_battery

  validates :voltage, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :notes, length: { maximum: 2_000 }
end
