module PlatformDetection
  extend ActiveSupport::Concern

  included do
    helper_method :detected_platform
  end

  private

  def detected_platform
    @detected_platform ||= Platform::Detector.detect(request.user_agent.to_s)
  end
end
