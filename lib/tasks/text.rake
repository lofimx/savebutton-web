namespace :kaya do
  namespace :text do
    desc "Enqueue plaintext extraction jobs for all existing bookmarks and PDFs"
    task extract_all: :environment do
      bookmark_count = 0
      pdf_count = 0

      # Enqueue extraction for all bookmarks (including those that previously failed caching)
      Bookmark.includes(:anga).find_each do |bookmark|
        next unless bookmark.anga
        next if bookmark.anga.text&.extracted?

        if bookmark.cached?
          ExtractPlaintextBookmarkJob.perform_later(bookmark.id)
          bookmark_count += 1
        else
          # Re-attempt caching for bookmarks that failed previously
          CacheBookmarkJob.perform_later(bookmark.id)
          bookmark_count += 1
        end
      end

      # Enqueue extraction for all PDFs
      Anga.where("filename LIKE ?", "%.pdf").find_each do |anga|
        next if anga.text&.extracted?
        next unless anga.file.attached?

        ExtractPlaintextPdfJob.perform_later(anga.id)
        pdf_count += 1
      end

      puts "Enqueued #{bookmark_count} bookmark extraction jobs and #{pdf_count} PDF extraction jobs."
    end
  end
end
