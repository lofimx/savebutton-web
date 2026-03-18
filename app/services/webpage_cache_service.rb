require "http"
require "nokogiri"
require "uri"
require "securerandom"

# WebpageCacheService downloads a webpage and its assets (CSS, JS, images)
# and stores them in a Bookmark's ActiveStorage attachments.
class WebpageCacheService
  TIMEOUT = 30
  MAX_ASSET_SIZE = 10.megabytes
  USER_AGENT = "Kaya/1.0 (Bookmark Cache)"

  # Asset types to download
  ASSET_SELECTORS = {
    css: 'link[rel="stylesheet"][href]',
    js: "script[src]",
    images: "img[src]"
  }.freeze

  def initialize(bookmark)
    @bookmark = bookmark
    @url = bookmark.url
    @base_uri = URI.parse(@url)
    @assets = []
  end

  def cache
    # Clear any previous error
    @bookmark.update(cache_error: nil)

    html_content = fetch_page
    unless html_content
      @bookmark.update(cache_error: "Failed to fetch webpage")
      return false
    end

    doc = Nokogiri::HTML(html_content)

    # Download favicon
    download_favicon(doc)

    # Download and rewrite asset URLs
    download_assets(doc)

    # Store the modified HTML
    store_html(doc.to_html)

    # Store all downloaded assets
    store_assets

    # Mark as cached (clear any error)
    @bookmark.update(cached_at: Time.current, cache_error: nil)

    true
  rescue StandardError => e
    error_message = "#{e.class}: #{e.message}"
    Rails.logger.error("WebpageCacheService error for #{@url}: #{error_message}")
    @bookmark.update(cache_error: error_message)
    false
  end

  private

  def fetch_page
    response = http_client.get(@url)
    return nil unless response.status.success?

    response.body.to_s
  rescue StandardError => e
    Rails.logger.error("Failed to fetch #{@url}: #{e.message}")
    nil
  end

  def download_assets(doc)
    # Download CSS files
    doc.css(ASSET_SELECTORS[:css]).each do |link|
      href = link["href"]
      next unless href

      asset_data = download_asset(href)
      if asset_data
        filename = generate_asset_filename(href, "css")
        @assets << { filename: filename, content: asset_data[:content], content_type: "text/css" }
        link["href"] = filename
      end
    end

    # Download JS files
    doc.css(ASSET_SELECTORS[:js]).each do |script|
      src = script["src"]
      next unless src

      asset_data = download_asset(src)
      if asset_data
        filename = generate_asset_filename(src, "js")
        @assets << { filename: filename, content: asset_data[:content], content_type: "application/javascript" }
        script["src"] = filename
      end
    end

    # Download images
    doc.css(ASSET_SELECTORS[:images]).each do |img|
      src = img["src"]
      next unless src
      next if src.start_with?("data:") # Skip data URIs

      asset_data = download_asset(src)
      if asset_data
        filename = generate_asset_filename(src, asset_data[:extension] || "bin")
        @assets << { filename: filename, content: asset_data[:content], content_type: asset_data[:content_type] }
        img["src"] = filename
      end
    end
  end

  def download_favicon(doc)
    # Try to find favicon from link tags (in order of preference)
    favicon_selectors = [
      'link[rel="icon"][href]',
      'link[rel="shortcut icon"][href]',
      'link[rel="apple-touch-icon"][href]',
      'link[rel="apple-touch-icon-precomposed"][href]'
    ]

    favicon_url = nil
    favicon_selectors.each do |selector|
      link = doc.at_css(selector)
      if link && link["href"].present?
        favicon_url = link["href"]
        break
      end
    end

    # Fallback to /favicon.ico if no link tag found
    favicon_url ||= "/favicon.ico"

    # Download the favicon
    absolute_url = resolve_url(favicon_url)
    return unless absolute_url

    response = http_client.get(absolute_url)
    return unless response.status.success?

    content = response.body.to_s
    return if content.empty? || content.bytesize > MAX_ASSET_SIZE

    content_type = response.content_type&.mime_type || "image/x-icon"

    unless content_type.start_with?("image/")
      Rails.logger.warn("🟠 WARN: Favicon for #{@url} returned non-image content type: #{content_type}")
      return
    end

    favicon = Files::Favicon.new(content, content_type)

    unless favicon.valid?
      Rails.logger.warn("🟠 WARN: Favicon for #{@url} failed image validation, discarding")
      return
    end

    @bookmark.favicon.attach(
      io: StringIO.new(favicon.content),
      filename: "favicon.ico",
      content_type: favicon.content_type
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to download favicon for #{@url}: #{e.message}")
  end

  def download_asset(url)
    absolute_url = resolve_url(url)
    return nil unless absolute_url

    response = http_client.get(absolute_url)
    return nil unless response.status.success?

    content = response.body.to_s
    return nil if content.bytesize > MAX_ASSET_SIZE

    content_type = response.content_type&.mime_type || "application/octet-stream"
    extension = extension_from_content_type(content_type) || extension_from_url(url)

    { content: content, content_type: content_type, extension: extension }
  rescue StandardError => e
    Rails.logger.warn("Failed to download asset #{url}: #{e.message}")
    nil
  end

  def resolve_url(url)
    return url if url.start_with?("http://", "https://")

    if url.start_with?("//")
      "#{@base_uri.scheme}:#{url}"
    elsif url.start_with?("/")
      "#{@base_uri.scheme}://#{@base_uri.host}#{url}"
    else
      # Relative URL
      base_path = @base_uri.path.sub(%r{/[^/]*$}, "/")
      "#{@base_uri.scheme}://#{@base_uri.host}#{base_path}#{url}"
    end
  rescue StandardError
    nil
  end

  def generate_asset_filename(url, extension)
    # Create a unique filename based on URL hash
    hash = Digest::SHA256.hexdigest(url)[0, 12]
    "asset_#{hash}.#{extension}"
  end

  def extension_from_content_type(content_type)
    case content_type
    when "text/css" then "css"
    when "application/javascript", "text/javascript" then "js"
    when "image/png" then "png"
    when "image/jpeg" then "jpg"
    when "image/gif" then "gif"
    when "image/webp" then "webp"
    when "image/svg+xml" then "svg"
    end
  end

  def extension_from_url(url)
    path = URI.parse(url).path rescue url
    ext = File.extname(path).delete(".")
    ext.empty? ? nil : ext
  end

  def store_html(html_content)
    @bookmark.html_file.attach(
      io: StringIO.new(html_content),
      filename: "index.html",
      content_type: "text/html"
    )
  end

  def store_assets
    @assets.each do |asset|
      @bookmark.assets.attach(
        io: StringIO.new(asset[:content]),
        filename: asset[:filename],
        content_type: asset[:content_type]
      )
    end
  end

  def http_client
    HTTP
      .timeout(TIMEOUT)
      .headers("User-Agent" => USER_AGENT)
      .follow(max_hops: 5)
  end
end
