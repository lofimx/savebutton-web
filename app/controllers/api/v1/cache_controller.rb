module Api
  module V1
    class CacheController < BaseController
      # GET /api/v1/cache
      # Lists all cached bookmark directories (URL-safe for direct use in URLs)
      # Filenames are stored URL-encoded in the DB; safety net ensures no unencoded characters slip through
      def index
        bookmarks = current_user.angas
                                .joins(:bookmark)
                                .where.not(bookmarks: { cached_at: nil })
                                .order(filename: :asc)

        # Return list of cache directory names (same as anga filenames), URL-safe
        filenames = bookmarks.pluck(:filename)
        safe_filenames = filenames.map { |f| Anga.ensure_url_safe(f) }
        directory_list = safe_filenames.join("\n")

        render plain: directory_list, content_type: "text/plain"
      end

      # GET /api/v1/cache/:bookmark
      # Lists all files in a cached bookmark directory (URL-safe for direct use in URLs)
      def show
        encoded_bookmark = ERB::Util.url_encode(CGI.unescape(params[:bookmark]))
        anga = current_user.angas.find_by(filename: encoded_bookmark)

        unless anga&.bookmark&.cached?
          head :not_found
          return
        end

        files = anga.bookmark.cached_file_list
        safe_files = files.map { |f| Anga.ensure_url_safe(f) }
        file_list = safe_files.join("\n")
        render plain: file_list, content_type: "text/plain"
      end

      # GET /api/v1/cache/:bookmark/:filename
      # Returns a specific cached file
      def file
        encoded_bookmark = ERB::Util.url_encode(CGI.unescape(params[:bookmark]))
        anga = current_user.angas.find_by(filename: encoded_bookmark)

        unless anga&.bookmark&.cached?
          head :not_found
          return
        end

        bookmark = anga.bookmark
        filename = params[:filename]

        if filename == "index.html" && bookmark.html_file.attached?
          send_data bookmark.html_file.download,
                    filename: "index.html",
                    type: "text/html",
                    disposition: "inline"
        elsif filename == "favicon.ico" && bookmark.favicon.attached?
          send_data bookmark.favicon.download,
                    filename: "favicon.ico",
                    type: bookmark.favicon.content_type,
                    disposition: "inline"
        else
          asset = bookmark.assets.find { |a| a.filename.to_s == filename }
          if asset
            send_data asset.download,
                      filename: filename,
                      type: asset.content_type,
                      disposition: "inline"
          else
            head :not_found
          end
        end
      end
    end
  end
end
