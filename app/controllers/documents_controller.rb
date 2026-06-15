class DocumentsController < ApplicationController
  before_action :set_vessel, only: %i[new create]

  def index
    @documents = Document.includes(:account, :asset).order(created_at: :desc)
  end

  def new
    @document = @vessel.documents.new(account: @vessel.account, document_type: "photo")
  end

  def create
    @document = @vessel.documents.new(document_params)
    @document.account = @vessel.account

    if @document.save
      redirect_to vessel_path(@vessel, anchor: "documents"), notice: "Document uploaded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_vessel
    @vessel = Asset.vessels.find(params[:vessel_id])
  end

  def document_params
    params.require(:document).permit(:title, :document_type, :notes, :file)
  end
end
