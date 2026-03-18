# == Schema Information
#
# Table name: bookmarks
# Database name: primary
#
#  id          :uuid             not null, primary key
#  cache_error :text
#  cached_at   :datetime
#  url         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  anga_id     :uuid             not null
#
# Indexes
#
#  index_bookmarks_on_anga_id  (anga_id)
#
# Foreign Keys
#
#  fk_rails_...  (anga_id => angas.id)
#
class Bookmark < ApplicationRecord
  belongs_to :anga

  # Main HTML file for the cached page
  has_one_attached :html_file

  # Favicon for the website
  has_one_attached :favicon

  # Associated assets (CSS, JS, images)
  has_many_attached :assets

  validates :url, presence: true

  # Returns the cache directory name (same as anga filename)
  def cache_directory_name
    anga.filename
  end

  # Returns true if the bookmark has been cached
  def cached?
    cached_at.present? && html_file.attached?
  end

  # Returns true if caching failed
  def cache_failed?
    cache_error.present?
  end

  # Returns true if caching is still pending (not cached and no error)
  def cache_pending?
    !cached? && !cache_failed?
  end

  # Returns a list of all cached file names for the API
  def cached_file_list
    files = []
    files << "index.html" if html_file.attached?
    files << "favicon.ico" if favicon.attached?
    assets.each do |asset|
      files << asset.filename.to_s
    end
    files
  end
end
