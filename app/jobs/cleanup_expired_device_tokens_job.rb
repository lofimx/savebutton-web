class CleanupExpiredDeviceTokensJob < ApplicationJob
  def perform
    count = DeviceToken.expired.delete_all
    Rails.logger.info "Auth: cleaned up #{count} expired device token(s)" if count > 0
  end
end
