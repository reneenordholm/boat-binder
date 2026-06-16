class ServiceVisitEngineReading < ApplicationRecord
  belongs_to :service_visit
  belongs_to :asset_engine

  validates :hours, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  delegate :display_name, to: :asset_engine
end
