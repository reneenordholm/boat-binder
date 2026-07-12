class AccountCreator
  attr_reader :account, :contact

  def self.call(account_attributes:, contact_attributes: nil)
    new(account_attributes: account_attributes, contact_attributes: contact_attributes).tap(&:save)
  end

  def initialize(account_attributes:, contact_attributes: nil)
    @account = Account.new(account_attributes)
    @contact_attributes = contact_attributes&.to_h
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
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    account.errors.add(:base, "Account could not be created with subscription state.") if account.errors.empty?
    false
  end

  def success?
    @success == true
  end

  private

  attr_reader :contact_attributes

  def build_contact
    return unless contact_attributes

    Contact.new(contact_attributes.merge(account: account))
  end

  def valid?
    account.valid?
    contact&.valid?

    account.errors.empty? && (contact.nil? || contact.errors.empty?)
  end
end
