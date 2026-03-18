require "erb"
require "cgi"

module FilenameEncoding
  extend ActiveSupport::Concern

  included do
    before_validation :encode_filename
  end

  class_methods do
    # Returns true if the filename contains only URL-safe characters
    # (RFC 3986 unreserved characters plus percent-encoded sequences)
    def filename_url_safe?(filename)
      filename.match?(/\A[A-Za-z0-9\-._~%]+\z/)
    end

    # Returns the filename as-is if already safe, otherwise URL-encodes it.
    # Use this as a safety net on API output to avoid double-encoding.
    def ensure_url_safe(filename)
      filename_url_safe?(filename) ? filename : ERB::Util.url_encode(filename)
    end
  end

  private

  # Normalizes the filename to its URL-encoded form.
  # Decode first (to handle already-encoded input), then re-encode.
  # This is idempotent: encoding a safe filename produces the same result.
  def encode_filename
    return if filename.blank?
    decoded = CGI.unescape(filename)
    self.filename = ERB::Util.url_encode(decoded)
  end
end
