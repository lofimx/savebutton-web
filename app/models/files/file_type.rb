# FileType wraps file extension logic and categorization for anga files.
# Use this model instead of hard-coding extension checks throughout the codebase.
#
# Example usage:
#   file_type = Files::FileType.new("document.pdf")
#   file_type.pdf?          # => true
#   file_type.preview_type  # => "pdf"
#   file_type.content_type  # => "application/pdf"
#
module Files
  class FileType
    # Preview types for the modal preview system
    PREVIEW_TYPES = {
      note: "note",
      bookmark: "bookmark",
      pdf: "pdf",
      image: "image",
      text: "text",
      other: "other"
    }.freeze

    # File extensions by category
    NOTE_EXTENSIONS = %w[.md].freeze
    BOOKMARK_EXTENSIONS = %w[.url].freeze
    PDF_EXTENSIONS = %w[.pdf].freeze
    IMAGE_EXTENSIONS = %w[.png .gif .jpg .jpeg .webp .svg .bmp .ico].freeze
    TEXT_EXTENSIONS = %w[.txt].freeze

    # All known extensions (used for exact-match search queries)
    ALL_EXTENSIONS = (NOTE_EXTENSIONS + BOOKMARK_EXTENSIONS + PDF_EXTENSIONS + IMAGE_EXTENSIONS + TEXT_EXTENSIONS).freeze

    # Common auto-generated filename patterns that shouldn't fuzzy-match
    COMMON_FILENAME_PATTERNS = %w[note bookmark].freeze

    # Extension to MIME type mapping
    # Note: script/sync.rb has its own copy for standalone operation
    CONTENT_TYPES = {
      ".md" => "text/markdown",
      ".url" => "text/plain",
      ".txt" => "text/plain",
      ".json" => "application/json",
      ".pdf" => "application/pdf",
      ".png" => "image/png",
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".gif" => "image/gif",
      ".webp" => "image/webp",
      ".svg" => "image/svg+xml",
      ".bmp" => "image/bmp",
      ".ico" => "image/x-icon",
      ".html" => "text/html",
      ".htm" => "text/html"
    }.freeze

    attr_reader :filename, :extension

    def initialize(filename)
      @filename = filename.to_s
      @extension = File.extname(@filename).downcase
    end

    # Type predicate methods
    def note?
      NOTE_EXTENSIONS.include?(extension)
    end

    def bookmark?
      BOOKMARK_EXTENSIONS.include?(extension)
    end

    def pdf?
      PDF_EXTENSIONS.include?(extension)
    end

    def image?
      IMAGE_EXTENSIONS.include?(extension)
    end

    def text?
      TEXT_EXTENSIONS.include?(extension)
    end

    # Returns the preview type for the modal preview system
    def preview_type
      if note?
        PREVIEW_TYPES[:note]
      elsif bookmark?
        PREVIEW_TYPES[:bookmark]
      elsif pdf?
        PREVIEW_TYPES[:pdf]
      elsif image?
        PREVIEW_TYPES[:image]
      elsif text?
        PREVIEW_TYPES[:text]
      else
        PREVIEW_TYPES[:other]
      end
    end

    # Returns the MIME content type for this file
    def content_type
      CONTENT_TYPES[extension] || "application/octet-stream"
    end

    # Returns the extension without the leading dot
    def extension_name
      extension.delete_prefix(".")
    end

    # Class methods for query/search logic

    # Check if a search query is an exact extension query (e.g., "pdf" or ".pdf")
    def self.exact_extension_query?(query)
      normalized = query.to_s.downcase.strip
      normalized = ".#{normalized}" unless normalized.start_with?(".")
      ALL_EXTENSIONS.include?(normalized)
    end

    # Check if a search query exactly matches a common filename pattern
    def self.common_pattern_query?(query)
      COMMON_FILENAME_PATTERNS.include?(query.to_s.downcase.strip)
    end

    # Check if a filename base (without timestamp/extension) is a common pattern
    def self.common_filename_pattern?(filename_base)
      COMMON_FILENAME_PATTERNS.include?(filename_base.to_s.downcase)
    end

    # Normalize a query to an extension (handles "pdf" and ".pdf")
    def self.normalize_extension_query(query)
      normalized = query.to_s.downcase.strip
      normalized.delete_prefix(".")
    end
  end
end
