class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.application.config.action_mailer.default_options&.fetch(:from, nil) || "no-reply@boat-binder.test" }
  layout "mailer"
end
