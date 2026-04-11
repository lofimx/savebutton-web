class CleanupExpiredAuthorizationCodesJob < ApplicationJob
  def perform
    count = AuthorizationCode.expired.delete_all
    Rails.logger.info "Auth: cleaned up #{count} expired authorization code(s)" if count > 0
  end
end
