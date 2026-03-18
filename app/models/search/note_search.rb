module Search
  class NoteSearch < BaseSearch
    protected

    def extract_content
      return nil unless @anga.file.attached?

      @anga.file.download
    rescue StandardError
      nil
    end
  end
end
