require "readability"
require "reverse_markdown"
require "nokogiri"

class ExtractPlaintextBookmarkJob < ApplicationJob
  queue_as :default

  # Tags whose content is not visible to users and should be stripped
  # before extracting body text for non-article pages.
  INVISIBLE_TAGS = %w[script style noscript].freeze

  def perform(bookmark_id)
    bookmark = Bookmark.find_by(id: bookmark_id)
    return unless bookmark
    return unless bookmark.cached? && bookmark.html_file.attached?

    anga = bookmark.anga
    words = anga.words || anga.build_words(source_type: "bookmark")

    begin
      html_content = bookmark.html_file.download.force_encoding("UTF-8")

      if article?(bookmark.url, html_content)
        Rails.logger.info "🔵 INFO: ExtractPlaintextBookmarkJob: Article detected for #{anga.filename}, using readability"
        plaintext = extract_article(html_content)
      else
        Rails.logger.info "🔵 INFO: ExtractPlaintextBookmarkJob: Non-article detected for #{anga.filename}, using body text extraction"
        plaintext = extract_body_text(html_content)
      end

      if plaintext.blank?
        Rails.logger.warn "🟠 WARN: ExtractPlaintextBookmarkJob: No readable content extracted from #{anga.filename}"
        words.update!(extract_error: "No readable content extracted")
        return
      end

      filename = "#{File.basename(anga.filename, '.*')}.md"
      words.file.attach(
        io: StringIO.new(plaintext),
        filename: filename,
        content_type: "text/markdown"
      )
      words.update!(extracted_at: Time.current, extract_error: nil)

      Rails.logger.info "🔵 INFO: ExtractPlaintextBookmarkJob: Extracted plaintext for #{anga.filename}"
    rescue => e
      Rails.logger.error "🔴 ERROR: ExtractPlaintextBookmarkJob: Failed to extract plaintext for #{anga.filename}: #{e.message}"
      words.update!(extract_error: "#{e.class}: #{e.message}")
    end
  end

  private

  def article?(url, html_content)
    ArticleFilters::ArticleUrlFilter.new(url).article? ||
      ArticleFilters::ArticleHtmlFilter.new(html_content).article?
  end

  def extract_article(html_content)
    readable = Readability::Document.new(html_content)
    readable_html = readable.content
    ReverseMarkdown.convert(readable_html, unknown_tags: :bypass).strip
  end

  def extract_body_text(html_content)
    doc = Nokogiri::HTML(html_content)

    body = doc.at_css("body")
    return "" unless body

    INVISIBLE_TAGS.each do |tag|
      body.css(tag).each(&:remove)
    end

    body.text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
  end
end
