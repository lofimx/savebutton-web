class AngaController < ApplicationController
  def preview
    @anga = Current.user.angas.find(params[:id])

    if @anga.file.attached?
      send_data @anga.file.download,
                filename: @anga.filename,
                type: @anga.file.content_type,
                disposition: "inline"
    else
      head :not_found
    end
  end

  # Returns the latest meta data for an anga as JSON
  def meta
    @anga = Current.user.angas.find(params[:id])
    latest_meta = @anga.metas.order(created_at: :desc).first

    if latest_meta&.file&.attached?
      begin
        toml_content = latest_meta.file.download.force_encoding("UTF-8")
        parsed = TomlRB.parse(toml_content)
        meta_section = parsed["meta"] || {}

        render json: {
          tags: meta_section["tags"] || [],
          note: meta_section["note"] || ""
        }
      rescue TomlRB::ParseError => e
        Rails.logger.warn "🟠 WARN: Failed to parse meta TOML for anga #{@anga.id}: #{e.message}"
        render json: { tags: [], note: "" }
      end
    else
      render json: { tags: [], note: "" }
    end
  end

  # Saves new meta data for an anga
  def save_meta
    @anga = Current.user.angas.find(params[:id])

    tags = params[:tags] || []
    note = params[:note] || ""

    # Build TOML content
    toml_content = build_meta_toml(@anga.filename, tags, note)

    # Generate filename for new meta record
    meta_filename = generate_meta_filename

    # Create new Meta record
    meta = Current.user.metas.new(
      filename: meta_filename,
      anga_filename: @anga.filename
    )
    meta.file.attach(
      io: StringIO.new(toml_content),
      filename: meta_filename,
      content_type: "application/toml"
    )

    if meta.save
      Rails.logger.info "🔵 INFO: Created meta #{meta_filename} for anga #{@anga.filename}"
      render json: { success: true, filename: meta_filename }
    else
      Rails.logger.error "🔴 ERROR: Failed to save meta: #{meta.errors.full_messages.join(', ')}"
      render json: { error: meta.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  # Returns cache status and triggers caching if needed
  def cache_status
    @anga = Current.user.angas.find(params[:id])
    bookmark = @anga.bookmark

    # If no bookmark record exists, try to create one from the .url file
    if bookmark.nil?
      file_type = Files::FileType.new(@anga.filename)
      unless file_type.bookmark? && @anga.file.attached?
        render json: { error: "Not a bookmark" }, status: :unprocessable_entity
        return
      end

      # Extract URL from the .url file
      url = @anga.bookmark_url
      unless url.present?
        render json: { error: "Could not extract URL from bookmark file" }, status: :unprocessable_entity
        return
      end

      # Create the bookmark record
      bookmark = @anga.create_bookmark!(url: url)
    end

    # If already cached, return the cache URL
    if bookmark.cached?
      render json: {
        status: "cached",
        cache_url: app_anga_cache_file_path(@anga, "index.html"),
        favicon_url: bookmark.favicon.attached? ? app_anga_cache_file_path(@anga, "favicon.ico") : nil
      }
      return
    end

    # If caching failed, return error status
    if bookmark.cache_failed?
      render json: {
        status: "error",
        error: bookmark.cache_error
      }
      return
    end

    # If not cached and no error, run the caching job synchronously
    # This ensures the user sees results immediately rather than waiting for async processing
    CacheBookmarkJob.perform_now(bookmark.id)

    # Check the result after the job completes
    bookmark.reload

    if bookmark.cached?
      render json: {
        status: "cached",
        cache_url: app_anga_cache_file_path(@anga, "index.html"),
        favicon_url: bookmark.favicon.attached? ? app_anga_cache_file_path(@anga, "favicon.ico") : nil
      }
    elsif bookmark.cache_failed?
      render json: {
        status: "error",
        error: bookmark.cache_error
      }
    else
      render json: { status: "pending" }
    end
  end

  # Serves cached bookmark files (HTML and assets)
  def cache_file
    @anga = Current.user.angas.find(params[:id])
    bookmark = @anga.bookmark

    unless bookmark&.cached?
      head :not_found
      return
    end

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

  def create
    if params[:file].present?
      create_from_file
    elsif params[:content].present?
      create_from_text
    else
      render json: { error: "No content or file provided" }, status: :unprocessable_entity
    end
  end

  private

  def create_from_file
    uploaded_file = params[:file]
    original_filename = uploaded_file.original_filename
    filename = generate_filename(original_filename)

    anga = Current.user.angas.new(filename: filename)
    file_type = Files::FileType.new(filename)

    anga.file.attach(
      io: uploaded_file.tempfile,
      filename: filename,
      content_type: file_type.content_type
    )

    if anga.save
      render json: { success: true, filename: filename }, status: :created
    else
      render json: { error: anga.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def create_from_text
    content = params[:content].to_s.strip
    type = params[:type]

    if type == "bookmark"
      filename = generate_filename("bookmark.url")
      file_content = "[InternetShortcut]\nURL=#{content}\n"
      content_type = "text/plain"
    else
      filename = generate_filename("note.md")
      file_content = content
      content_type = "text/markdown"
    end

    anga = Current.user.angas.new(filename: filename)
    anga.file.attach(
      io: StringIO.new(file_content),
      filename: filename,
      content_type: content_type
    )

    if anga.save
      render json: { success: true, filename: filename }, status: :created
    else
      render json: { error: anga.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def generate_filename(original_name)
    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H%M%S")
    base_filename = "#{timestamp}-#{original_name}"

    # Check for collision and add nanoseconds if needed
    if Current.user.angas.exists?(filename: base_filename)
      nanoseconds = Time.now.utc.nsec.to_s.rjust(9, "0")
      timestamp_with_ns = "#{timestamp}_#{nanoseconds}"
      "#{timestamp_with_ns}-#{original_name}"
    else
      base_filename
    end
  end

  def generate_meta_filename
    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H%M%S")
    base_filename = "#{timestamp}-meta.toml"

    # Check for collision and add nanoseconds if needed
    if Current.user.metas.exists?(filename: base_filename)
      nanoseconds = Time.now.utc.nsec.to_s.rjust(9, "0")
      timestamp_with_ns = "#{timestamp}_#{nanoseconds}"
      "#{timestamp_with_ns}-meta.toml"
    else
      base_filename
    end
  end

  def build_meta_toml(anga_filename, tags, note)
    toml_data = {
      "anga" => {
        "filename" => anga_filename
      },
      "meta" => {}
    }

    # Only add tags if present
    if tags.is_a?(Array) && tags.any?
      toml_data["meta"]["tags"] = tags
    end

    # Only add note if present
    if note.present?
      toml_data["meta"]["note"] = note
    end

    TomlRB.dump(toml_data)
  end
end
