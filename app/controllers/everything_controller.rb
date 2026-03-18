class EverythingController < ApplicationController
  def index
    if params[:q].present?
      # Search results are already ordered by relevance (highest score first)
      @angas = SearchService.new(Current.user, params[:q]).search
    else
      @angas = Current.user.angas
                      .includes(:file_attachment)
                      .order(filename: :desc)
    end
  end
end
