module Admin
  class VersionsController < BaseController
    def index
      scope = PaperTrail::Version.order(created_at: :desc)
      if params[:user_id].present?
        @user = User.find_by(id: params[:user_id])
        if @user
          # Versions whose whodunnit is this admin or whose item is this user.
          scope = scope.where(whodunnit: @user.id).or(scope.where(item_type: "User", item_id: @user.id))
        end
      end
      @versions = scope.limit(200)
    end
  end
end
