class BinderNotesController < ApplicationController
  before_action :set_vessel

  def create
    @binder_note = @vessel.binder_notes.new(binder_note_params)
    @binder_note.account = @vessel.account

    if @binder_note.save
      redirect_to vessel_path(@vessel, anchor: "notes"), notice: "Note added."
    else
      redirect_to vessel_path(@vessel, anchor: "notes"), alert: @binder_note.errors.full_messages.to_sentence
    end
  end

  private

  def set_vessel
    @vessel = Asset.vessels.find(params[:vessel_id])
  end

  def binder_note_params
    params.require(:binder_note).permit(:title, :body, :note_type)
  end
end
