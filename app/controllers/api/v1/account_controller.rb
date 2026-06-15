module Api
  module V1
    class AccountController < BaseController
      before_action :authorize_user_access

      # GET /api/v1/:user_email/account
      # Returns subscription/account state so clients can show banners
      # without attempting an upload.
      def show
        subscription = current_user.subscription
        render json: {
          tier: subscription.tier,
          stripe_status: subscription.stripe_status,
          restricted: current_user.restricted?,
          in_grace_period: subscription.in_grace_period?,
          grace_period_ends_at: subscription.grace_period_ends_at,
          bytes_used: subscription.bytes_used,
          quota_bytes: serialize_quota(subscription.quota_bytes),
          approaching_quota: subscription.approaching_quota?,
          slop_enabled: subscription.slop_enabled
        }
      end

      private

      def authorize_user_access
        unless current_user.email_address == params[:user_email].downcase.strip
          head :forbidden
        end
      end

      def serialize_quota(quota)
        return nil if quota == Float::INFINITY
        quota
      end
    end
  end
end
