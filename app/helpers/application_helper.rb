module ApplicationHelper
  # Decodes a URL-encoded filename for human-readable display in the UI.
  # Filenames are stored URL-encoded in the DB but users should see
  # the decoded form (e.g. spaces instead of %20).
  def display_filename(filename)
    CGI.unescape(filename)
  end
end
