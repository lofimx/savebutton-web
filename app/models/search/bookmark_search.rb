module Search
  class BookmarkSearch < BaseSearch
    protected

    def extract_content
      parts = []

      # Include the bookmark URL in searchable content
      if @anga.bookmark&.url.present?
        parts << @anga.bookmark.url
      end

      # Include extracted plaintext from the Words model
      words = @anga.words
      if words&.extracted? && words.file.attached?
        parts << words.file.download.force_encoding("UTF-8")
      end

      parts.join("\n").presence
    rescue StandardError => e
      Rails.logger.warn("BookmarkSearch: Failed to read content for #{@anga.filename}: #{e.message}")
      nil
    end
  end
end
