require "nokogiri"

# ArticleHtmlFilter checks whether HTML content matches known article/blog
# generator patterns. Used by ExtractPlaintextBookmarkJob to decide between
# readability extraction (for articles) and full-body text extraction.
#
# Example usage:
#   filter = ArticleFilters::ArticleHtmlFilter.new('<html><head><meta name="generator" content="WordPress 6.4"></head>...')
#   filter.article?  # => true
#
#   filter = ArticleFilters::ArticleHtmlFilter.new('<html><body><div>Just a regular page</div></body></html>')
#   filter.article?  # => false
#
module ArticleFilters
  class ArticleHtmlFilter
    # CMS/blog generator names to match in <meta name="generator"> content attribute.
    # Case-insensitive matching against the content value.
    GENERATOR_PATTERNS = %w[
      WordPress
      Ghost
      Hugo
      Jekyll
      Blogger
      Drupal
      Joomla
      Hexo
      Pelican
      Gatsby
      Eleventy
      11ty
      Astro
      Next.js
      Nuxt
    ].freeze

    # Schema.org JSON-LD @type values that indicate article content.
    SCHEMA_ARTICLE_TYPES = %w[
      Article
      NewsArticle
      BlogPosting
    ].freeze

    attr_reader :html

    def initialize(html)
      @html = html.to_s
    end

    def article?
      doc = Nokogiri::HTML(@html)

      generator_match?(doc) || og_article?(doc) || schema_article?(doc)
    end

    private

    # Check <meta name="generator" content="WordPress|Ghost|...">
    def generator_match?(doc)
      generator = doc.at_css('meta[name="generator"]')&.[]("content")
      return false if generator.blank?

      generator_down = generator.downcase
      GENERATOR_PATTERNS.any? { |pattern| generator_down.include?(pattern.downcase) }
    end

    # Check <meta property="og:type" content="article">
    def og_article?(doc)
      og_type = doc.at_css('meta[property="og:type"]')&.[]("content")
      og_type&.downcase&.strip == "article"
    end

    # Check for Schema.org JSON-LD with @type containing Article, NewsArticle, or BlogPosting
    def schema_article?(doc)
      doc.css('script[type="application/ld+json"]').each do |script|
        json_text = script.text
        next unless SCHEMA_ARTICLE_TYPES.any? { |type| json_text.include?(type) }

        begin
          data = JSON.parse(json_text)
          return true if schema_type_match?(data)
        rescue JSON::ParserError
          next
        end
      end

      false
    end

    def schema_type_match?(data)
      case data
      when Hash
        type_value = data["@type"]
        case type_value
        when String
          SCHEMA_ARTICLE_TYPES.include?(type_value)
        when Array
          type_value.any? { |t| SCHEMA_ARTICLE_TYPES.include?(t) }
        end
      when Array
        data.any? { |item| schema_type_match?(item) }
      end
    end
  end
end
