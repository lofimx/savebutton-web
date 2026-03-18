require "erb"
require "cgi"

namespace :kaya do
  namespace :db_filenames do
    desc "Check for any URL-unsafe filenames stored in angas and metas tables"
    task check: :environment do
      unsafe = find_unsafe_filenames
      total = unsafe[:angas].size + unsafe[:metas].size

      if total == 0
        puts "All filenames are URL-safe."
      else
        unsafe[:angas].each do |anga|
          puts "  Anga #{anga.id}: '#{anga.filename}'"
        end
        unsafe[:metas].each do |meta|
          puts "  Meta #{meta.id}: '#{meta.filename}'"
        end
        puts "Found #{total} URL-unsafe filename(s)."
      end
    end

    desc "URL-encode any existing filenames in angas and metas tables that contain URL-unsafe characters"
    task encode: :environment do
      unsafe = find_unsafe_filenames
      total = unsafe[:angas].size + unsafe[:metas].size

      if total == 0
        puts "All filenames are already URL-safe. Nothing to do."
        next
      end

      total_updated = 0

      ActiveRecord::Base.transaction do
        unsafe[:angas].each do |anga|
          old_filename = anga.filename
          new_filename = ERB::Util.url_encode(CGI.unescape(old_filename))

          if old_filename != new_filename
            anga.update_column(:filename, new_filename)
            total_updated += 1
            Rails.logger.info "🔵 INFO: Encoded anga filename: '#{old_filename}' -> '#{new_filename}'"
            puts "  Anga #{anga.id}: '#{old_filename}' -> '#{new_filename}'"
          end
        end

        unsafe[:metas].each do |meta|
          old_filename = meta.filename
          new_filename = ERB::Util.url_encode(CGI.unescape(old_filename))

          if old_filename != new_filename
            meta.update_column(:filename, new_filename)
            total_updated += 1
            Rails.logger.info "🔵 INFO: Encoded meta filename: '#{old_filename}' -> '#{new_filename}'"
            puts "  Meta #{meta.id}: '#{old_filename}' -> '#{new_filename}'"
          end
        end
      end

      puts "Done. Updated #{total_updated} filename(s)."
    end

    # Returns a hash of { angas: [...], metas: [...] } records with URL-unsafe filenames.
    def find_unsafe_filenames
      url_safe_pattern = /\A[A-Za-z0-9\-._~%]+\z/

      unsafe_angas = Anga.find_each.reject { |a| a.filename.match?(url_safe_pattern) }
      unsafe_metas = Meta.find_each.reject { |m| m.filename.match?(url_safe_pattern) }

      { angas: unsafe_angas, metas: unsafe_metas }
    end
  end
end
