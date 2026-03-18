# == Schema Information
#
# Table name: metas
# Database name: primary
#
#  id            :uuid             not null, primary key
#  anga_filename :string           not null
#  filename      :string           not null
#  orphan        :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  anga_id       :uuid
#  user_id       :uuid             not null
#
# Indexes
#
#  index_metas_on_anga_id               (anga_id)
#  index_metas_on_user_id               (user_id)
#  index_metas_on_user_id_and_filename  (user_id,filename) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (anga_id => angas.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
class Meta < ApplicationRecord
  include FilenameEncoding

  before_save :link_to_anga

  belongs_to :user
  belongs_to :anga, optional: true
  has_one_attached :file

  validates :filename, presence: true
  validates :filename, uniqueness: { scope: :user_id }
  validates :filename, format: {
    with: /\A\d{4}-\d{2}-\d{2}T\d{6}(_\d{9})?.*\.toml\z/,
    message: "must start with YYYY-mm-ddTHHMMSS format and end with .toml"
  }
  validates :anga_filename, presence: true

  scope :orphaned, -> { where(orphan: true) }
  scope :linked, -> { where(orphan: false) }

  # Extracts the anga filename from TOML content.
  # Returns the filename string or nil if not found/invalid.
  def self.extract_anga_filename(uploaded_file)
    toml_content = uploaded_file.read
    uploaded_file.rewind
    parsed = TomlRB.parse(toml_content)
    parsed.dig("anga", "filename")
  rescue TomlRB::ParseError => e
    Rails.logger.warn "🟠 WARN: Failed to parse meta TOML: #{e.message}"
    nil
  end

  private

  # Look up the associated Anga by the anga_filename and link them.
  # If the Anga cannot be found, mark this Meta as orphan.
  # Encodes the anga_filename before lookup since anga filenames are stored URL-encoded.
  def link_to_anga
    encoded_anga_filename = ERB::Util.url_encode(CGI.unescape(anga_filename))
    found_anga = user.angas.find_by(filename: encoded_anga_filename)

    if found_anga
      self.anga = found_anga
      self.orphan = false
    else
      self.anga = nil
      self.orphan = true
    end
  end
end
