class Reminder < ApplicationRecord
  REMINDER_TYPES = %w[maintenance insurance registration inspection other].freeze
  STATUSES = %w[pending completed].freeze

  belongs_to :asset

  validates :title, :due_date, presence: true
  validates :title, length: { maximum: 120 }
  validates :reminder_type, inclusion: { in: REMINDER_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :completed, -> { where(status: "completed") }
  scope :upcoming, -> { pending.order(:due_date) }

  def complete!
    update!(status: "completed")
  end
end
