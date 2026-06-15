class ServiceVisit < ApplicationRecord
  belongs_to :asset
  belongs_to :performed_by_user, class_name: "User"
  has_many_attached :photos

  validates :visit_date, presence: true
  validates :engine_hours, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :summary, :condition_notes, :follow_up_notes, length: { maximum: 2_000 }

  scope :recent, -> { order(visit_date: :desc, created_at: :desc) }
end
