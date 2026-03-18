# == Schema Information
#
# Table name: words
# Database name: primary
#
#  id            :uuid             not null, primary key
#  extract_error :text
#  extracted_at  :datetime
#  source_type   :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  anga_id       :uuid             not null
#
# Indexes
#
#  index_words_on_anga_id  (anga_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (anga_id => angas.id)
#
class Words < ApplicationRecord
  belongs_to :anga

  has_one_attached :file

  validates :source_type, presence: true, inclusion: { in: %w[bookmark pdf] }

  def extracted?
    extracted_at.present? && file.attached?
  end

  def extract_failed?
    extract_error.present?
  end

  def extract_pending?
    !extracted? && !extract_failed?
  end

  # Returns the words filename for the API
  # Bookmarks: {anga_filename}.md
  # PDFs: {anga_filename}.txt
  def words_filename
    base = anga.filename
    case source_type
    when "bookmark"
      "#{File.basename(base, '.*')}.md"
    when "pdf"
      "#{File.basename(base, '.*')}.txt"
    end
  end
end
