module Search
  class GenericFileSearch < BaseSearch
    protected

    # Generic files (images, etc.) don't have extractable text content,
    # so we only search the filename. The base class handles this.
    def extract_content
      nil
    end
  end
end
