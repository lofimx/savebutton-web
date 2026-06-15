# Idempotent seed data. Safe to re-run.
#
# Run with: bin/rails db:seed

if Rails.env.development?
  %w[free basic advanced friend].each do |tier|
    email = "#{tier}@example.com"
    user = User.find_or_create_by!(email_address: email) do |u|
      u.password = "password"
    end
    sub = user.subscription || user.create_subscription!(tier: :free)
    sub.update!(tier: tier.to_sym)
    puts "Seeded #{email} (tier: #{tier})"
  end
end
