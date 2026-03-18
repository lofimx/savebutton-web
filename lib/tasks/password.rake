namespace :kaya do
  namespace :password do
    desc "Reset a user's password by email. Usage: rake kaya:password:reset EMAIL=user@example.com"
    task reset: :environment do
      email = ENV["EMAIL"]

      if email.blank?
        $stderr.puts "Error: EMAIL is required. Usage: rake kaya:password:reset EMAIL=user@example.com"
        exit 1
      end

      normalized_email = email.strip.downcase
      user = User.find_by(email_address: normalized_email)

      if user.nil?
        $stderr.puts "Error: No user found with email '#{normalized_email}'."
        exit 1
      end

      new_password = SecureRandom.hex(16)
      user.update!(password: new_password, incidental_password: false)
      user.sessions.destroy_all

      Rails.logger.info "🔵 INFO: Password reset for user '#{normalized_email}' by administrator."

      puts new_password
    end
  end
end
