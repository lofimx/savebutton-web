# Favicon handles validation and sanitization of favicon image data.
# Used during bookmark caching to detect broken favicons and, where
# possible, convert them to a browser-safe format (PNG).
#
# Example usage:
#   favicon = Files::Favicon.new(image_data, "image/vnd.microsoft.icon")
#   favicon.valid?        # => true/false
#   favicon.content       # => sanitized image data (PNG for ICO files)
#   favicon.content_type  # => sanitized content type
#
module Files
  class Favicon
    ICO_CONTENT_TYPES = %w[image/x-icon image/vnd.microsoft.icon].freeze

    attr_reader :content, :content_type

    def initialize(content, content_type)
      @content = content
      @content_type = content_type
      sanitize_if_ico
    end

    def valid?
      if ico?
        valid_ico?
      else
        valid_image_via_magick?
      end
    rescue StandardError => e
      Rails.logger.warn("🟠 WARN: Favicon validation error: #{e.message}")
      false
    end

    private

    def ico?
      ICO_CONTENT_TYPES.include?(@content_type) || ico_magic_bytes?
    end

    def ico_magic_bytes?
      @content.bytesize >= 6 && @content.getbyte(0) == 0 && @content.getbyte(1) == 0 &&
        @content.getbyte(2) == 1 && @content.getbyte(3) == 0
    end

    # Attempts to sanitize an ICO file by converting it to PNG via MiniMagick.
    # If the ICO is valid, the original data is preserved.
    # If the ICO has structural issues but MiniMagick can still read it,
    # the image is converted to PNG so browsers can render it.
    # If conversion fails entirely, the original data is kept and valid? will return false.
    def sanitize_if_ico
      return unless ico?
      return if valid_ico?

      convert_to_png
    rescue StandardError => e
      Rails.logger.warn("🟠 WARN: ICO sanitization failed for favicon: #{e.message}")
    end

    def convert_to_png
      tempfile = Tempfile.new([ "favicon", ".ico" ])
      tempfile.binmode
      tempfile.write(@content)
      tempfile.close

      image = MiniMagick::Image.open(tempfile.path)
      return unless image.valid?

      image.format "png"
      png_data = File.binread(image.path)

      @content = png_data
      @content_type = "image/png"

      Rails.logger.info("🔵 INFO: Converted broken ICO favicon to PNG (#{png_data.bytesize} bytes)")
    ensure
      tempfile&.unlink
    end

    # Validates an ICO file by checking that directory entry dimensions match
    # the actual BMP/PNG sub-image dimensions. Browsers enforce this consistency
    # and reject ICO files where they disagree.
    def valid_ico?
      bytes = @content.bytes
      return false if bytes.length < 6

      num_images = bytes[4] | (bytes[5] << 8)
      return false if num_images == 0
      return false if bytes.length < 6 + (num_images * 16)

      num_images.times do |i|
        entry_offset = 6 + (i * 16)
        dir_width = bytes[entry_offset] == 0 ? 256 : bytes[entry_offset]
        dir_height = bytes[entry_offset + 1] == 0 ? 256 : bytes[entry_offset + 1]
        img_size = bytes[entry_offset + 8] | (bytes[entry_offset + 9] << 8) |
                   (bytes[entry_offset + 10] << 16) | (bytes[entry_offset + 11] << 24)
        img_offset = bytes[entry_offset + 12] | (bytes[entry_offset + 13] << 8) |
                     (bytes[entry_offset + 14] << 16) | (bytes[entry_offset + 15] << 24)

        return false if img_offset + img_size > bytes.length

        return false if img_offset + 8 > bytes.length

        sub_magic = bytes[img_offset, 4]
        if sub_magic == [ 137, 80, 78, 71 ] # PNG
          # PNG sub-images: browsers trust the PNG header, directory dims are informational
          next
        end

        # BMP sub-image: validate directory dimensions match BMP header dimensions
        bmp_header_size = sub_magic[0] | (sub_magic[1] << 8) | (sub_magic[2] << 16) | (sub_magic[3] << 24)
        return false unless bmp_header_size == 40 # BITMAPINFOHEADER

        bmp_width = bytes[img_offset + 4] | (bytes[img_offset + 5] << 8) |
                    (bytes[img_offset + 6] << 16) | (bytes[img_offset + 7] << 24)
        bmp_raw_height = bytes[img_offset + 8] | (bytes[img_offset + 9] << 8) |
                         (bytes[img_offset + 10] << 16) | (bytes[img_offset + 11] << 24)
        bmp_height = bmp_raw_height / 2 # ICO BMP height includes image + mask

        unless dir_width == bmp_width && dir_height == bmp_height
          Rails.logger.debug("🟢 DEBUG: ICO directory says #{dir_width}x#{dir_height} but BMP says #{bmp_width}x#{bmp_height}")
          return false
        end
      end

      true
    end

    def valid_image_via_magick?
      tempfile = Tempfile.new([ "favicon", ".img" ])
      tempfile.binmode
      tempfile.write(@content)
      tempfile.close

      image = MiniMagick::Image.open(tempfile.path)
      image.valid?
    ensure
      tempfile&.unlink
    end
  end
end
