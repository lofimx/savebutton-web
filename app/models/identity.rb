# == Schema Information
#
# Table name: identities
# Database name: primary
#
#  id         :uuid             not null, primary key
#  provider   :string           not null
#  uid        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_identities_on_provider_and_uid  (provider,uid) UNIQUE
#  index_identities_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Identity < ApplicationRecord
  has_paper_trail
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :provider, inclusion: { in: %w[google_oauth2 apple microsoft_graph] }
end
