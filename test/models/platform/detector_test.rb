require "test_helper"

class Platform::DetectorTest < ActiveSupport::TestCase
  test "detects Chrome on Windows" do
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    result = Platform::Detector.detect(ua)
    assert_equal :chrome, result.browser
    assert_equal :windows, result.os
    assert result.chromium_based?
  end

  test "detects Firefox on Linux" do
    ua = "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0"
    result = Platform::Detector.detect(ua)
    assert_equal :firefox, result.browser
    assert_equal :linux, result.os
    refute result.chromium_based?
  end

  test "detects Safari on macOS" do
    ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    result = Platform::Detector.detect(ua)
    assert_equal :safari, result.browser
    assert_equal :macos, result.os
    refute result.chromium_based?
  end

  test "detects Edge on Windows" do
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
    result = Platform::Detector.detect(ua)
    assert_equal :edge, result.browser
    assert_equal :windows, result.os
  end

  test "detects Vivaldi" do
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Vivaldi/6.5.3206.50"
    result = Platform::Detector.detect(ua)
    assert_equal :vivaldi, result.browser
  end

  test "detects Brave" do
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Brave Chrome/120.0.0.0 Safari/537.36"
    result = Platform::Detector.detect(ua)
    assert_equal :brave, result.browser
  end

  test "detects Opera as chromium" do
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 OPR/106.0.0.0"
    result = Platform::Detector.detect(ua)
    assert_equal :chromium, result.browser
  end

  test "detects Mobile Safari on iOS" do
    ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    result = Platform::Detector.detect(ua)
    assert_equal :safari, result.browser
    assert_equal :ios, result.os
  end

  test "detects Chrome Mobile on Android" do
    ua = "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
    result = Platform::Detector.detect(ua)
    assert_equal :chrome, result.browser
    assert_equal :android, result.os
  end

  test "returns unknown for nil user agent" do
    result = Platform::Detector.detect(nil)
    assert_equal :unknown, result.browser
    assert_equal :unknown, result.os
    refute result.chromium_based?
  end

  test "returns unknown for empty user agent" do
    result = Platform::Detector.detect("")
    assert_equal :unknown, result.browser
    assert_equal :unknown, result.os
  end

  test "chromium_based is true for Chrome" do
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    result = Platform::Detector.detect(ua)
    assert result.chromium_based?
  end

  test "detects actual Chromium browser" do
    ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chromium/120.0.0.0 Chrome/120.0.0.0 Safari/537.36"
    result = Platform::Detector.detect(ua)
    assert_equal :chromium, result.browser
    assert result.chromium_based?
  end

  test "chromium_based is false for firefox" do
    ua = "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0"
    result = Platform::Detector.detect(ua)
    refute result.chromium_based?
  end
end
