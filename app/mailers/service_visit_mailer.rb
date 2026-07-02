class ServiceVisitMailer < ApplicationMailer
  helper ApplicationHelper

  def summary(service_visit, recipient_email)
    @service_visit = service_visit
    @vessel = service_visit.asset
    @issue_notes = []

    mail(
      subject: "#{@vessel.name} service visit report - #{@service_visit.visit_date.to_fs(:long)}",
      to: recipient_email
    )
  end
end
