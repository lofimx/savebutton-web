module Api
  module V1
    class AngaController < BaseController
      before_action :authorize_user_access
      before_action :set_anga, only: [ :show ]

      # GET /api/v1/:user_email/anga
      # Returns a text/plain list of files (URL-safe for direct use in URLs)
      # Filenames are stored URL-encoded in the DB; safety net ensures no unencoded characters slip through
      def index
        filenames = current_user.angas.order(:filename).pluck(:filename)
        safe_filenames = filenames.map { |f| Anga.ensure_url_safe(f) }
        render plain: safe_filenames.join("\n"), content_type: "text/plain"
      end

      # GET /api/v1/:user_email/anga/:filename
      # Returns the file content
      def show
        if @anga.file.attached?
          send_data @anga.file.download,
            filename: @anga.filename,
            type: @anga.file.content_type,
            disposition: "inline"
        else
          head :not_found
        end
      end

      # POST /api/v1/:user_email/anga/:filename
      # Uploads a file
      def create
        if current_user.restricted?
          render plain: "Account restricted", status: :forbidden
          return
        end

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
        if current_user.angas.exists?(filename: encoded_filename)
          render plain: "File already exists: #{url_filename}",
                 status: :conflict # 409
          return
        end

        quota_response = enforce_quota(url_filename, uploaded_file.size)
        if quota_response
          render plain: quota_response[:message], status: quota_response[:status]
          return
        end

        # Create the anga record with attached file
        # The model's before_validation callback will URL-encode the filename
        @anga = current_user.angas.new(filename: url_filename)
        @anga.file.attach(uploaded_file)

        if @anga.save
          start_grace_if_overage(uploaded_file.size)
          head :created
        else
          render plain: @anga.errors.full_messages.join(", "), status: :unprocessable_entity
        end
      end

      private

      # Returns nil if the upload is allowed, otherwise a hash with :status and :message.
      def enforce_quota(filename, size)
        subscription = current_user.subscription
        cap = Subscription.single_file_cap_bytes(filename)

        if cap
          # Structural file (.url, -note/-quote/-blurb.md): 1 MB cap at every tier, including friend.
          return { status: :content_too_large, message: "File exceeds #{cap} bytes" } if size > cap
          return nil
        end

        # Non-structural file (counts toward GB quota).
        if subscription.free?
          return { status: :content_too_large, message: "Free tier does not allow this file type" }
        end

        return nil if subscription.friend?

        # Paid tier (basic/advanced).
        return nil if subscription.in_grace_period?

        if subscription.over_quota?(size)
          # Already over quota (no grace, no buffer) → reject.
          if subscription.over_quota?(0)
            return { status: :payment_required, message: "Quota exceeded" }
          end
          # This POST is what crosses the boundary — start grace and allow.
          # (start_grace_if_overage runs after the save and will start grace.)
        end

        nil
      end

      # If the saved upload pushed the user over quota (paid tiers only), start grace.
      def start_grace_if_overage(size)
        subscription = current_user.subscription.reload
        return unless subscription.stripe_backed?
        return unless subscription.over_quota?
        subscription.start_grace_period!
      end

      def authorize_user_access
        unless current_user.email_address == params[:user_email].downcase.strip
          head :forbidden
        end
      end

      def set_anga
        encoded_filename = ERB::Util.url_encode(CGI.unescape(params[:filename]))
        @anga = current_user.angas.find_by!(filename: encoded_filename)
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def extract_uploaded_file
        if params[:file].is_a?(ActionDispatch::Http::UploadedFile)
          params[:file]
        elsif request.content_type == "application/octet-stream" && request.body.present?
          # Handle raw binary upload - create an UploadedFile-like object
          url_filename = CGI.unescape(params[:filename])
          content_type = Rack::Mime.mime_type(File.extname(url_filename))

          tempfile = Tempfile.new([ "anga", File.extname(url_filename) ])
          tempfile.binmode
          tempfile.write(request.body.read)
          tempfile.rewind

          ActionDispatch::Http::UploadedFile.new(
            filename: url_filename,
            type: content_type,
            tempfile: tempfile
          )
        end
      end
    end
  end
end
