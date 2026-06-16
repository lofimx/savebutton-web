namespace :kaya do
  namespace :staff do
    desc "Promote a user to staff role. Usage: bin/rails 'kaya:staff:promote[user@example.com]'"
    task :promote, [ :email ] => :environment do |_t, args|
      email = args[:email].to_s

      if email.blank?
        $stderr.puts "Error: email is required. Usage: bin/rails 'kaya:staff:promote[user@example.com]'"
        exit 1
      end

      normalized_email = email.strip.downcase
      user = User.find_by(email_address: normalized_email)

      if user.nil?
        $stderr.puts "Error: No user found with email '#{normalized_email}'."
        exit 1
      end

      if user.staff?
        puts "User '#{normalized_email}' is already staff."
      else
        user.update!(role: "staff")
        Rails.logger.info "🔵 INFO: User '#{normalized_email}' promoted to staff."
        puts "Promoted '#{normalized_email}' to staff."
      end
    end

    desc "Demote a user from staff to regular user. Usage: bin/rails 'kaya:staff:demote[user@example.com]'"
    task :demote, [ :email ] => :environment do |_t, args|
      email = args[:email].to_s

      if email.blank?
        $stderr.puts "Error: email is required. Usage: bin/rails 'kaya:staff:demote[user@example.com]'"
        exit 1
      end

      normalized_email = email.strip.downcase
      user = User.find_by(email_address: normalized_email)

      if user.nil?
        $stderr.puts "Error: No user found with email '#{normalized_email}'."
        exit 1
      end

      if user.user?
        puts "User '#{normalized_email}' is already a regular user."
      else
        user.update!(role: "user")
        Rails.logger.info "🔵 INFO: User '#{normalized_email}' demoted from staff."
        puts "Demoted '#{normalized_email}' from staff."
      end
    end
  end
end
