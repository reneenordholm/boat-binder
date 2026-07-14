class AccountCreator
  attr_reader :account, :contact

  def self.call(account_attributes:, contact_attributes: nil)
    new(account_attributes: account_attributes, contact_attributes: contact_attributes).tap(&:save)
  end

  def initialize(account_attributes:, contact_attributes: nil)
    @account_attributes = account_attributes.to_h
    @contact_attributes = contact_attributes&.to_h
    @account = Account.new(@account_attributes)
    @contact = build_contact
  end

  def save
    @success = false
    return false unless valid?

    Account.transaction do
      account.save!
      account.create_subscription!(Subscription.default_local_attributes)
      contact&.save!
    end

    @success = true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    rebuild_models_after_rollback(error)
    false
  end

  def success?
    @success == true
  end

  private

  attr_reader :account_attributes, :contact_attributes

  def build_contact
    return unless contact_attributes

    Contact.new(contact_attributes.merge(account: account))
  end

  def valid?
    account.valid?
    contact&.valid?

    account.errors.empty? && (contact.nil? || contact.errors.empty?)
  end

  def rebuild_models_after_rollback(error)
    account_errors = account.errors.full_messages
    contact_errors = contact&.errors&.full_messages || []

    @account = Account.new(account_attributes)
    @contact = build_contact

    account_errors.each { |message| account.errors.add(:base, message) }
    contact_errors.each { |message| contact&.errors&.add(:base, message) }

    add_failure_error(error)
  end

  def add_failure_error(error)
    record = error.respond_to?(:record) ? error.record : nil

    if record&.errors&.any?
      record.errors.full_messages.each { |message| account.errors.add(:base, message) }
    end

    account.errors.add(:base, "Account could not be created with subscription state.")
  end
end
