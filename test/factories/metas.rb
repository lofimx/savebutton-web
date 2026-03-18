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
FactoryBot.define do
  factory :meta do
    user
    sequence(:filename) { |n| "#{Time.now.utc.strftime('%Y-%m-%dT%H%M%S')}-meta-#{n}.toml" }
    sequence(:anga_filename) { |n| "#{Time.now.utc.strftime('%Y-%m-%dT%H%M%S')}-bookmark-#{n}.url" }

    after(:build) do |meta|
      unless meta.file.attached?
        toml_content = <<~TOML
          [anga]
          filename = "#{meta.anga_filename}"

          [meta]
          tags = ["example", "test"]
          note = '''Sample note for testing.'''
        TOML
        meta.file.attach(
          io: StringIO.new(toml_content),
          filename: meta.filename,
          content_type: "application/toml"
        )
      end
    end

    # Trait for meta that references an existing anga (linked)
    trait :linked do
      transient do
        linked_anga { nil }
      end

      after(:build) do |meta, evaluator|
        if evaluator.linked_anga
          meta.anga_filename = evaluator.linked_anga.filename
          toml_content = <<~TOML
            [anga]
            filename = "#{meta.anga_filename}"

            [meta]
            tags = ["example", "test"]
            note = '''Sample note for testing.'''
          TOML
          meta.file.attach(
            io: StringIO.new(toml_content),
            filename: meta.filename,
            content_type: "application/toml"
          )
        end
      end
    end
  end
end
