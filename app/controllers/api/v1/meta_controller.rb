module Api
  module V1
    class MetaController < BaseController
      before_action :authorize_user_access
      before_action :set_meta, only: [ :show ]

      # GET /api/v1/:user_email/meta
      # Returns a text/plain list of meta files (URL-safe for direct use in URLs)
      # Filenames are stored URL-encoded in the DB; safety net ensures no unencoded characters slip through
      def index
        filenames = current_user.metas.order(:filename).pluck(:filename)
        safe_filenames = filenames.map { |f| Meta.ensure_url_safe(f) }
        render plain: safe_filenames.join("\n"), content_type: "text/plain"
      end

      # GET /api/v1/:user_email/meta/:filename
      # Returns the meta file content
      def show
        if @meta.file.attached?
          send_data @meta.file.download,
            filename: @meta.filename,
            type: "application/toml",
            disposition: "inline"
        else
          head :not_found
        end
      end

      # POST /api/v1/:user_email/meta/:filename
      # Uploads a meta file
      def create
        url_filename = CGI.unescape(params[:filename])
        encoded_filename = ERB::Util.url_encode(url_filename)

        # Validate filename from Content-Disposition matches URL filename
        uploaded_file = extract_uploaded_file
        if uploaded_file.nil?
          render plain: "No file provided", status: :bad_request
          return
        end

        disposition_filename = uploaded_file.original_filename
        if disposition_filename != url_filename
          render plain: "Filename mismatch: Content-Disposition filename '#{disposition_filename}' does not match URL filename '#{url_filename}'",
                 status: :expectation_failed # 417
          return
        end

        # Check for collision using encoded filename (as stored in DB)
        if current_user.metas.exists?(filename: encoded_filename)
          render plain: "File already exists: #{url_filename}",
                 status: :conflict # 409
          return
        end

        anga_filename = Meta.extract_anga_filename(uploaded_file)
        if anga_filename.nil?
          render plain: "Invalid TOML: must contain [anga] section with filename key",
                 status: :unprocessable_entity
          return
        end

        # Create the meta record with attached file
        @meta = current_user.metas.new(
          filename: url_filename,
          anga_filename: anga_filename
        )
        uploaded_file.rewind
        @meta.file.attach(uploaded_file)

        if @meta.save
          head :created
        else
          render plain: @meta.errors.full_messages.join(", "), status: :unprocessable_entity
        end
      end

      private

      def authorize_user_access
        unless current_user.email_address == params[:user_email].downcase.strip
          head :forbidden
        end
      end

      def set_meta
        encoded_filename = ERB::Util.url_encode(CGI.unescape(params[:filename]))
        @meta = current_user.metas.find_by!(filename: encoded_filename)
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def extract_uploaded_file
        if params[:file].is_a?(ActionDispatch::Http::UploadedFile)
          params[:file]
        elsif request.content_type == "application/octet-stream" && request.body.present?
          # Handle raw binary upload - create an UploadedFile-like object
          url_filename = CGI.unescape(params[:filename])

          tempfile = Tempfile.new([ "meta", ".toml" ])
          tempfile.binmode
          tempfile.write(request.body.read)
          tempfile.rewind

          ActionDispatch::Http::UploadedFile.new(
            filename: url_filename,
            type: "application/toml",
            tempfile: tempfile
          )
        end
      end
    end
  end
end
