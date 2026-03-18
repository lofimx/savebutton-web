require "test_helper"

class ExtractPlaintextPdfJobTest < ActiveJob::TestCase
  test "does nothing for non-existent anga" do
    assert_nothing_raised do
      ExtractPlaintextPdfJob.perform_now(SecureRandom.uuid)
    end
  end

  test "does nothing when file is not attached" do
    user = create(:user)
    anga = user.angas.new(filename: "2024-01-01T120000-no-file.pdf")
    anga.id = SecureRandom.uuid
    Anga.insert({
      id: anga.id,
      user_id: user.id,
      filename: anga.filename,
      created_at: Time.current,
      updated_at: Time.current
    })

    ExtractPlaintextPdfJob.perform_now(anga.id)

    anga_reloaded = Anga.find(anga.id)
    assert_nil anga_reloaded.words
  end

  test "records error for invalid PDF data" do
    user = create(:user)
    anga = create(:anga, :pdf, user: user, filename: "2024-01-01T120000-corrupt.pdf")

    ExtractPlaintextPdfJob.perform_now(anga.id)

    anga.reload
    assert anga.words.present?
    assert_not anga.words.extracted?
    assert anga.words.extract_error.present?
  end

  test "updates existing words record on re-extraction" do
    user = create(:user)
    anga = create(:anga, :pdf, user: user, filename: "2024-01-01T120000-retry.pdf")

    # Create an existing failed words record
    anga.create_words!(source_type: "pdf", extract_error: "Previous failure")

    ExtractPlaintextPdfJob.perform_now(anga.id)

    anga.reload
    assert anga.words.present?
    # The fake PDF data in the factory will fail, so it should still have an error
    assert anga.words.extract_error.present?
  end
end
