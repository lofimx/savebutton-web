module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_staff
    before_action :set_paper_trail_whodunnit

    private

    def require_staff
      head :not_found unless Current.user&.staff?
    end

    def user_for_paper_trail
      Current.user&.id
    end
  end
end
