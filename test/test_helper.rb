ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Add more helper methods to be used by all tests here...
    def create_account(name: "Hayes Yacht Company", account_type: "client")
      Account.create!(name: name, account_type: account_type)
    end

    def create_user(email: "captain@example.test", role: "captain")
      User.create!(
        email_address: email,
        password: "password",
        password_confirmation: "password",
        role: role
      )
    end

    def create_asset(account: create_account, asset_type: "vessel")
      Asset.create!(
        account: account,
        asset_type: asset_type,
        name: "Blue Meridian",
        make: "Sabre",
        model: "48 Salon Express",
        year: 2020,
        length: 48,
        marina: "Bainbridge Marina",
        slip: "C-18"
      )
    end

    def create_vessel(account: create_account)
      create_asset(account: account, asset_type: "vessel")
    end
  end
end
