class DocumentsController < ApplicationController
  before_action :require_write_access!, except: %i[index]
  before_action :set_vessel, only: %i[new create]
  before_action :require_document_write_access!, only: %i[new create]
  before_action :set_document, only: %i[destroy]
  before_action :require_existing_document_write_access!, only: %i[destroy]
  before_action :set_form_collections, only: %i[new create]

  def index
    @documents = scoped_documents.includes(:account, :asset).order(created_at: :desc)
  end

  def new
    @document = if @vessel
      @vessel.documents.new(account: @vessel.account, document_type: "photo")
    else
      Document.new(document_type: "registration")
    end
  end

  def create
    @document = if @vessel
      @vessel.documents.new(document_params)
    else
      Document.new(document_params)
    end
    return unless assign_document_relationships(@document)

    if @document.save
      redirect_to after_create_path, notice: "Document uploaded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    fallback_vessel = @document.asset if @document.asset&.asset_type == "vessel"
    @document.file.purge if @document.file.attached?
    @document.destroy!

    redirect_to fallback_location(fallback_vessel), notice: "Document removed."
  end

  private

  def set_vessel
    @vessel = scoped_vessels.find_by!(slug: params[:vessel_id]) if params[:vessel_id].present?
  end

  def set_document
    @document = scoped_documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :document_type, :notes, :file)
  end

  def set_form_collections
    @accounts = manageable_accounts.active.ordered
    @vessels = manageable_vessels.active.includes(:account).ordered
  end

  def assign_document_relationships(document)
    if @vessel
      document.account = @vessel.account
      return true
    end

    return true if document_account_id.blank? && document_asset_id.blank?

    unless can_manage_document_relationships?
      deny_access!
      return false
    end

    if document_asset_id.present?
      document.asset = manageable_vessels.find(document_asset_id)
      if document_account_id.present? && document_account_id.to_i != document.asset.account_id
        document.errors.add(:asset, "must belong to the selected owner")
        render :new, status: :unprocessable_entity
        return false
      end

      document.account = document.asset.account
    elsif document_account_id.present?
      document.account = manageable_accounts.find(document_account_id)
    end

    true
  end

  def document_account_id
    params.require(:document)[:account_id]
  end

  def document_asset_id
    params.require(:document)[:asset_id]
  end

  def can_manage_document_relationships?
    can_manage_records?
  end

  def require_document_write_access!
    return require_write_access!(@vessel.account) if @vessel

    require_write_access!
  end

  def require_existing_document_write_access!
    require_write_access!(@document.account)
  end

  def after_create_path
    if @document.asset&.asset_type == "vessel"
      vessel_path(@document.asset, anchor: "documents")
    else
      documents_path
    end
  end

  def fallback_location(vessel)
    if vessel
      vessel_path(vessel, anchor: "documents")
    else
      documents_path
    end
  end
end
