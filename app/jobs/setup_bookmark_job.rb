class SetupBookmarkJob < ApplicationJob
  queue_as :default
  retry_on ActiveStorage::FileNotFoundError, wait: 1.second, attempts: 10

  def perform(anga_id)
    anga = Anga.find_by(id: anga_id)
    return unless anga
    return unless anga.bookmark_file?
    return if anga.bookmark.present?

    url = anga.extract_url_from_content
    unless url.present?
      Rails.logger.warn "🟠 WARN: SetupBookmarkJob: Could not extract URL from #{anga.filename}"
      return
    end

    Rails.logger.info "🔵 INFO: Setting up bookmark for #{anga.filename}"
    bookmark = anga.create_bookmark!(url: url)
    CacheBookmarkJob.perform_later(bookmark.id)
  end
end
