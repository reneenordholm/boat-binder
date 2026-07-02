class ServiceVisit < ApplicationRecord
  DEFAULT_INSPECTION_LABELS = [
    "Hull",
    "Bilge",
    "Shore power",
    "Dock lines",
    "Interior",
    "Systems",
    "Batteries",
    "Engine room",
    "Safety equipment"
  ].freeze

  belongs_to :asset
  belongs_to :performed_by_user, class_name: "User"
  has_many :service_visit_engine_readings, dependent: :destroy
  has_many :service_visit_inspection_checks, dependent: :destroy
  has_many :service_visit_battery_checks, dependent: :destroy
  has_many_attached :photos

  validates :visit_date, presence: true
  validates :engine_hours, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :summary, :condition_notes, :follow_up_notes, length: { maximum: 2_000 }

  scope :recent, -> { order(visit_date: :desc, created_at: :desc) }

  def summary_recipient_email
    owner_summary_recipient&.email_address.presence || contact_summary_recipient&.email.presence
  end

  def build_workflow_defaults
    build_default_engine_readings
    build_default_inspection_checks
    build_default_battery_checks
  end

  def ordered_engine_readings
    service_visit_engine_readings.sort_by { |reading| [ reading.asset_engine.position, reading.asset_engine.name ] }
  end

  def ordered_inspection_checks
    service_visit_inspection_checks.sort_by { |check| [ check.position, check.id || 0 ] }
  end

  def ordered_battery_checks
    service_visit_battery_checks.sort_by { |check| check.asset_battery.name }
  end

  private

  def owner_summary_recipient
    asset.account.account_memberships.active.includes(:user).order(:id).map(&:user).find do |user|
      user.owner? && user.active? && user.email_address.present?
    end
  end

  def contact_summary_recipient
    asset.account.primary_contact
  end

  def build_default_engine_readings
    asset.ensure_default_engines!

    asset.active_engines.each do |engine|
      next if service_visit_engine_readings.any? { |reading| reading.asset_engine == engine }

      service_visit_engine_readings.build(asset_engine: engine)
    end
  end

  def build_default_inspection_checks
    DEFAULT_INSPECTION_LABELS.each_with_index do |label, index|
      next if service_visit_inspection_checks.any? { |check| check.label == label }

      service_visit_inspection_checks.build(label: label, position: index + 1)
    end
  end

  def build_default_battery_checks
    asset.active_batteries.each do |battery|
      next if service_visit_battery_checks.any? { |check| check.asset_battery == battery }

      service_visit_battery_checks.build(asset_battery: battery)
    end
  end
end
