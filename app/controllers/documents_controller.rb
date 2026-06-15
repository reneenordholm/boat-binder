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

  def destroy
    @document = Document.find(params[:id])
    fallback_vessel = @document.asset if @document.asset&.asset_type == "vessel"
    @document.file.purge if @document.file.attached?
    @document.destroy!

    redirect_to fallback_location(fallback_vessel), notice: "Document removed."
  end

  private

  def set_vessel
    @vessel = Asset.vessels.find_by!(slug: params[:vessel_id])
  end

  def document_params
    params.require(:document).permit(:title, :document_type, :notes, :file)
  end

  def fallback_location(vessel)
    if vessel
      vessel_path(vessel, anchor: "documents")
    else
      documents_path
    end
  end
end
