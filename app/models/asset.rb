class Asset < ApplicationRecord
  ASSET_TYPES = %w[vessel home pet audit other].freeze

  belongs_to :account
  has_many :service_visits, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :binder_notes, dependent: :destroy
  has_many :documents, dependent: :destroy

  before_validation :normalize_text_fields
  before_validation :ensure_slug

  validates :asset_type, inclusion: { in: ASSET_TYPES }
  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { scope: [ :account_id, :asset_type ] }
  validates :slug, presence: true, uniqueness: true
  validates :make, :model, :marina, :slip, :registration_number, length: { maximum: 120 }
  validates :year, numericality: { only_integer: true, greater_than: 1900, less_than_or_equal_to: Date.current.year + 1 }, allow_blank: true
  validates :length, numericality: { greater_than: 0 }, allow_blank: true
  validates :registration_number, uniqueness: { scope: :account_id }, allow_blank: true

  scope :vessels, -> { where(asset_type: "vessel") }
  scope :ordered, -> { order(:name) }
  scope :search, ->(query) {
    next all if query.blank?

    normalized_query = "%#{sanitize_sql_like(query.to_s.strip)}%"
    left_outer_joins(:account).where(
      "assets.name ILIKE :query OR accounts.name ILIKE :query OR assets.marina ILIKE :query OR assets.slip ILIKE :query",
      query: normalized_query
    )
  }

  def to_param
    slug
  end

  def owner_name
    owner_contact&.name || account.name
  end

  def owner_contact
    account.contacts.find { |contact| contact.role.to_s.downcase.include?("owner") }
  end

  def primary_contact
    owner_contact || account.contacts.first
  end

  def last_visit
    service_visits.recent.first
  end

  def next_reminder
    reminders.upcoming.first
  end

  def overdue_reminders
    reminders.pending.where("due_date < ?", Date.current).order(:due_date)
  end

  def open_follow_up_visits
    service_visits.where(follow_up_needed: true).recent
  end

  def display_model
    [ year, make, model ].compact_blank.join(" ")
  end

  def location_label
    [ marina, slip.present? ? "Slip #{slip}" : nil ].compact.join(", ").presence || "Location not set"
  end

  def status_label
    return "Needs attention" if overdue_reminders.exists? || open_follow_up_visits.exists?
    return "Scheduled" if next_reminder.present?

    "Clear"
  end

  def status_tone
    return :urgent if overdue_reminders.exists? || open_follow_up_visits.exists?
    return :warning if next_reminder.present?

    :success
  end

  private

  def normalize_text_fields
    %i[name make model marina slip registration_number notes].each do |attribute|
      value = public_send(attribute)
      next unless value.respond_to?(:squish)

      normalized_value = value.squish
      normalized_value = nil if normalized_value.blank? && attribute == :registration_number
      public_send("#{attribute}=", normalized_value)
    end
  end

  def ensure_slug
    return if name.blank? || (slug.present? && !will_save_change_to_name?)

    base_slug = name.parameterize.presence || "vessel"
    candidate = base_slug
    suffix = 2

    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
