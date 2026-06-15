class ServiceVisitsController < ApplicationController
  before_action :set_vessel

  def index
    @service_visits = @vessel.service_visits.includes(:performed_by_user).recent
  end

  def new
    @service_visit = @vessel.service_visits.new(
      visit_date: Date.current,
      performed_by_user: Current.user,
      location: default_location
    )
  end

  def create
    @service_visit = @vessel.service_visits.new(service_visit_params)
    @service_visit.performed_by_user = Current.user

    if @service_visit.save
      create_issue_note if issue_note_present?
      redirect_to vessel_service_visit_path(@vessel, @service_visit), notice: "Visit report saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @service_visit = @vessel.service_visits.includes(photos_attachments: :blob).find(params[:id])
    @issue_notes = @vessel.binder_notes.where(note_type: "issue").order(created_at: :desc).limit(3)
  end

  private

  def set_vessel
    @vessel = Asset.vessels.find(params[:vessel_id])
  end

  def service_visit_params
    params.require(:service_visit).permit(
      :visit_date,
      :engine_hours,
      :location,
      :summary,
      :condition_notes,
      :follow_up_needed,
      :follow_up_notes,
      photos: []
    )
  end

  def issue_note_present?
    params[:issue_title].present? || params[:issue_body].present?
  end

  def create_issue_note
    @vessel.binder_notes.create!(
      account: @vessel.account,
      title: params[:issue_title].presence || "Issue from #{@service_visit.visit_date.to_fs(:long)}",
      body: params[:issue_body].presence || "Issue noted during vessel visit.",
      note_type: "issue"
    )
  end

  def default_location
    [ @vessel.marina, @vessel.slip.presence && "Slip #{@vessel.slip}" ].compact.join(", ")
  end
end
