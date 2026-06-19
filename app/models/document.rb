class Document < ApplicationRecord
  DOCUMENT_TYPES = %w[insurance registration maintenance_record receipt marina_contract photo other].freeze
  ALLOWED_FILE_CONTENT_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
    image/webp
  ].freeze
  MAX_FILE_SIZE = 25.megabytes

  belongs_to :account
  belongs_to :asset, optional: true
  has_one_attached :file

  validates :title, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 2_000 }
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validate :asset_belongs_to_account
  validate :file_is_safe_upload

  private

  def asset_belongs_to_account
    return if asset.blank? || account_id.blank? || asset.account_id == account_id

    errors.add(:asset, "must belong to the selected owner")
  end

  def file_is_safe_upload
    return unless file.attached?

    unsafe_upload = false

    unless ALLOWED_FILE_CONTENT_TYPES.include?(file.blob.content_type.to_s)
      errors.add(:file, "must be a PDF, JPEG, PNG, or WEBP file")
      unsafe_upload = true
    end

    if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, "must be 25 MB or smaller")
      unsafe_upload = true
    end

    file.purge if unsafe_upload
  end
end
