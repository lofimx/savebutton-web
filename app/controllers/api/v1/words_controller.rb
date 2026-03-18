module Api
  module V1
    class WordsController < BaseController
      before_action :authorize_user_access

      # GET /api/v1/:user_email/words
      # Lists all anga directories that have extracted words (URL-safe for direct use in URLs)
      # Filenames are stored URL-encoded in the DB; safety net ensures no unencoded characters slip through
      def index
        filenames = current_user.angas
                                .joins(:words)
                                .where.not(words: { extracted_at: nil })
                                .order(filename: :asc)
                                .pluck(:filename)

        safe_filenames = filenames.map { |f| Anga.ensure_url_safe(f) }
        render plain: safe_filenames.join("\n"), content_type: "text/plain"
      end

      # GET /api/v1/:user_email/words/:anga
      # Lists words files for a given anga directory (URL-safe for direct use in URLs)
      def show
        encoded_anga = ERB::Util.url_encode(CGI.unescape(params[:anga]))
        anga = current_user.angas.find_by(filename: encoded_anga)
        words = anga&.words

        unless words&.extracted?
          head :not_found
          return
        end

        safe_filename = Anga.ensure_url_safe(words.words_filename)
        render plain: safe_filename, content_type: "text/plain"
      end

      # GET /api/v1/:user_email/words/:anga/:filename
      # Returns the plaintext file content
      def file
        encoded_anga = ERB::Util.url_encode(CGI.unescape(params[:anga]))
        anga = current_user.angas.find_by(filename: encoded_anga)
        words = anga&.words

        unless words&.extracted? && words.file.attached?
          head :not_found
          return
        end

        requested_filename = CGI.unescape(params[:filename])
        unless words.words_filename == requested_filename
          head :not_found
          return
        end

        content_type = words.source_type == "bookmark" ? "text/markdown" : "text/plain"
        send_data words.file.download,
                  filename: words.words_filename,
                  type: content_type,
                  disposition: "inline"
      end

      private

      def authorize_user_access
        unless current_user.email_address == params[:user_email].downcase.strip
          head :forbidden
        end
      end
    end
  end
end
