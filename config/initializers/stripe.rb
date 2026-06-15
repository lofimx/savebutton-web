stripe_credentials = Rails.application.credentials.stripe

if stripe_credentials.present? && stripe_credentials[:secret_key].present?
  Stripe.api_key = stripe_credentials[:secret_key]
end

# Boot-time warning for incomplete Stripe configuration. Skipped in test
# (tests stub credentials inline where needed).
unless Rails.env.test?
  required_keys = %i[secret_key webhook_signing_secret basic_price_id advanced_price_id]
  missing_keys = required_keys.reject { |k| stripe_credentials&.dig(k).present? }

  if missing_keys.any?
    Rails.logger.warn "🟠 WARN: Stripe credentials incomplete (missing: #{missing_keys.join(', ')}). Billing will fail until set via `bin/rails credentials:edit --environment #{Rails.env}`."
  end
end
