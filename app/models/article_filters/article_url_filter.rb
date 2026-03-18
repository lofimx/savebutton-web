# ArticleUrlFilter checks whether a URL belongs to a known news or article
# website. Used by ExtractPlaintextBookmarkJob to decide between readability
# extraction (for articles) and full-body text extraction (for everything else).
#
# Example usage:
#   filter = ArticleFilters::ArticleUrlFilter.new("https://www.nytimes.com/2026/01/15/technology/ai-update.html")
#   filter.article?  # => true
#
#   filter = ArticleFilters::ArticleUrlFilter.new("https://bort.likes.it.com/moment/hPpWbvcHWe")
#   filter.article?  # => false
#
module ArticleFilters
  class ArticleUrlFilter
    # Known news/journalism domains where readability extraction is appropriate.
    # Subdomains are handled by checking if the host ends with the domain.
    ARTICLE_DOMAINS = %w[
      nytimes.com
      cnn.com
      foxnews.com
      bbc.com
      bbc.co.uk
      reuters.com
      apnews.com
      washingtonpost.com
      theguardian.com
      wsj.com
      nbcnews.com
      abcnews.go.com
      cbsnews.com
      cnbc.com
      politico.com
      axios.com
      vox.com
      theverge.com
      usatoday.com
      latimes.com
      nypost.com
      independent.co.uk
      telegraph.co.uk
      aljazeera.com
      dw.com
      npr.org
      msnbc.com
      thehill.com
      bloomberg.com
      ft.com
      economist.com
      arstechnica.com
      wired.com
      techcrunch.com
      theatlantic.com
      newyorker.com
      slate.com
      salon.com
      buzzfeednews.com
      thedailybeast.com
    ].freeze

    attr_reader :url

    def initialize(url)
      @url = url.to_s
    end

    def article?
      host = extract_host
      return false if host.blank?

      ARTICLE_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
    end

    private

    def extract_host
      URI.parse(@url).host&.downcase
    rescue URI::InvalidURIError
      nil
    end
  end
end
