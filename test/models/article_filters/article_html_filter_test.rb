require "test_helper"

class ArticleFilters::ArticleHtmlFilterTest < ActiveSupport::TestCase
  # --- Generator meta tag ---

  test "article? returns true for WordPress generator" do
    html = '<html><head><meta name="generator" content="WordPress 6.4.2"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for Hugo generator" do
    html = '<html><head><meta name="generator" content="Hugo 0.121.0"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for Ghost generator" do
    html = '<html><head><meta name="generator" content="Ghost 5.0"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for Jekyll generator" do
    html = '<html><head><meta name="generator" content="Jekyll v4.3.2"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for Drupal generator" do
    html = '<html><head><meta name="generator" content="Drupal 10"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for Blogger generator" do
    html = '<html><head><meta content="blogger" name="generator"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  # --- Open Graph article type ---

  test "article? returns true for og:type article" do
    html = '<html><head><meta property="og:type" content="article"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for og:type Article (capitalized)" do
    html = '<html><head><meta property="og:type" content="Article"></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns false for og:type website" do
    html = '<html><head><meta property="og:type" content="website"></head><body></body></html>'
    assert_not ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  # --- Schema.org JSON-LD ---

  test "article? returns true for JSON-LD Article type" do
    html = '<html><head><script type="application/ld+json">{"@type": "Article", "headline": "Test"}</script></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for JSON-LD NewsArticle type" do
    html = '<html><head><script type="application/ld+json">{"@type": "NewsArticle", "headline": "Test"}</script></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for JSON-LD BlogPosting type" do
    html = '<html><head><script type="application/ld+json">{"@type": "BlogPosting", "headline": "Test"}</script></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns true for JSON-LD array with Article" do
    html = '<html><head><script type="application/ld+json">[{"@type": "WebSite"}, {"@type": "Article"}]</script></head><body></body></html>'
    assert ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  # --- Non-article pages ---

  test "article? returns false for page without any article signals" do
    html = "<html><head><title>Dashboard</title></head><body><div>Stats</div></body></html>"
    assert_not ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  test "article? returns false for the non-article fixture page" do
    html = File.read(Rails.root.join("test/fixtures/files/non_article_page_timeline_likes_it_com.html"))
    assert_not ArticleFilters::ArticleHtmlFilter.new(html).article?
  end

  # --- Edge cases ---

  test "article? returns false for empty HTML" do
    assert_not ArticleFilters::ArticleHtmlFilter.new("").article?
  end

  test "article? returns false for nil HTML" do
    assert_not ArticleFilters::ArticleHtmlFilter.new(nil).article?
  end

  test "article? handles malformed JSON-LD gracefully" do
    html = '<html><head><script type="application/ld+json">{broken json</script></head><body></body></html>'
    assert_not ArticleFilters::ArticleHtmlFilter.new(html).article?
  end
end
