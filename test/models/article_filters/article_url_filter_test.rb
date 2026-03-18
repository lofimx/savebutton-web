require "test_helper"

class ArticleFilters::ArticleUrlFilterTest < ActiveSupport::TestCase
  test "article? returns true for nytimes.com" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://www.nytimes.com/2026/01/15/technology/article.html")
    assert filter.article?
  end

  test "article? returns true for bare domain without www" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://nytimes.com/article")
    assert filter.article?
  end

  test "article? returns true for subdomain of known domain" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://cooking.nytimes.com/recipes/123")
    assert filter.article?
  end

  test "article? returns true for bbc.co.uk" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://www.bbc.co.uk/news/world-12345")
    assert filter.article?
  end

  test "article? returns true for techcrunch.com" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://techcrunch.com/2026/02/28/startup-news/")
    assert filter.article?
  end

  test "article? returns true for reuters.com" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://www.reuters.com/world/some-article")
    assert filter.article?
  end

  test "article? returns true for theguardian.com" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://www.theguardian.com/technology/2026/feb/28/article")
    assert filter.article?
  end

  test "article? returns false for unknown domain" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://bort.likes.it.com/moment/hPpWbvcHWe")
    assert_not filter.article?
  end

  test "article? returns false for generic site" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://example.com/page")
    assert_not filter.article?
  end

  test "article? returns false for empty URL" do
    filter = ArticleFilters::ArticleUrlFilter.new("")
    assert_not filter.article?
  end

  test "article? returns false for nil URL" do
    filter = ArticleFilters::ArticleUrlFilter.new(nil)
    assert_not filter.article?
  end

  test "article? returns false for malformed URL" do
    filter = ArticleFilters::ArticleUrlFilter.new("not a url at all")
    assert_not filter.article?
  end

  test "article? does not match partial domain names" do
    filter = ArticleFilters::ArticleUrlFilter.new("https://fakenytimes.com/article")
    assert_not filter.article?
  end
end
