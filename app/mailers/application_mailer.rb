class ApplicationMailer < ActionMailer::Base
  DELIVERY_ERRORS = [
    Net::SMTPError,
    IOError,
    SocketError,
    SystemCallError,
    Timeout::Error
  ].freeze

  default from: -> { Rails.application.config.action_mailer.default_options&.fetch(:from, nil) || "no-reply@boat-binder.test" }
  layout "mailer"
end
