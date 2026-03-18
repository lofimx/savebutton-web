require "pdf-reader"

class ExtractPlaintextPdfJob < ApplicationJob
  queue_as :default

  def perform(anga_id)
    anga = Anga.find_by(id: anga_id)
    return unless anga
    return unless anga.file.attached?

    words = anga.words || anga.build_words(source_type: "pdf")

    begin
      tempfile = Tempfile.new([ "pdf_extract", ".pdf" ])
      tempfile.binmode
      tempfile.write(anga.file.download)
      tempfile.rewind

      reader = PDF::Reader.new(tempfile.path)
      plaintext = reader.pages.map(&:text).join("\n\n").strip

      if plaintext.blank?
        Rails.logger.warn "🟠 WARN: ExtractPlaintextPdfJob: No text content extracted from #{anga.filename}"
        words.update!(extract_error: "No text content extracted")
        return
      end

      filename = "#{File.basename(anga.filename, '.*')}.txt"
      words.file.attach(
        io: StringIO.new(plaintext),
        filename: filename,
        content_type: "text/plain"
      )
      words.update!(extracted_at: Time.current, extract_error: nil)

      Rails.logger.info "🔵 INFO: ExtractPlaintextPdfJob: Extracted plaintext for #{anga.filename}"
    rescue => e
      Rails.logger.error "🔴 ERROR: ExtractPlaintextPdfJob: Failed to extract plaintext for #{anga.filename}: #{e.message}"
      words.update!(extract_error: "#{e.class}: #{e.message}")
    ensure
      if tempfile
        tempfile.close
        tempfile.unlink
      end
    end
  end
end
