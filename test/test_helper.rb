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

    def create_user(email: "captain@example.test", role: "captain", name: nil, active: true)
      User.create!(
        name: name,
        email_address: email,
        password: "password",
        password_confirmation: "password",
        role: role,
        active: active
      )
    end

    def create_account_membership(user:, account:, access_level: "read_only", active: true)
      AccountMembership.create!(
        user: user,
        account: account,
        access_level: access_level,
        active: active
      )
    end

    def create_asset(account: create_account, asset_type: "vessel", name: "Blue Meridian")
      Asset.create!(
        account: account,
        asset_type: asset_type,
        name: name,
        make: "Sabre",
        model: "48 Salon Express",
        year: 2020,
        length: 48,
        marina: "Bainbridge Marina",
        slip: "C-18"
      )
    end

    def create_vessel(account: create_account, name: "Blue Meridian")
      create_asset(account: account, asset_type: "vessel", name: name)
    end

    def create_battery(asset: create_vessel, name: "House Battery 1")
      AssetBattery.create!(
        asset: asset,
        name: name,
        location: "Engine room",
        battery_type: "AGM"
      )
    end

    def sign_in_as(user = create_user)
      post session_path, params: {
        email_address: user.email_address,
        password: "password"
      }
    end
  end
end
