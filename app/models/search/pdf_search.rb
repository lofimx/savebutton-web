module Search
  class PdfSearch < BaseSearch
    protected

    def extract_content
      words = @anga.words
      return nil unless words&.extracted? && words.file.attached?

      words.file.download.force_encoding("UTF-8")
    rescue StandardError => e
      Rails.logger.warn("PdfSearch: Failed to read extracted words for #{@anga.filename}: #{e.message}")
      nil
    end
  end
end
