# SearchService orchestrates full-text search across all anga types.
# It delegates to specialized search objects in app/models/search/ for
# each file type.
class SearchService
  # Minimum Jaro-Winkler score to consider a match (0.0 to 1.0)
  DEFAULT_THRESHOLD = 0.75

  def initialize(user, query, threshold: DEFAULT_THRESHOLD)
    @user = user
    @query = query.to_s.strip.downcase
    @threshold = threshold
  end

  # Returns an array of angas ordered by relevance score (highest first)
  def search
    return [] if @query.blank?

    matches = []

    @user.angas.includes(:file_attachment, :file_blob, :words, :bookmark).find_each do |anga|
      result = search_anga(anga)
      matches << { anga: anga, score: result.score } if result.match?
    end

    # Sort by score descending (most relevant first)
    matches.sort_by { |m| -m[:score] }.map { |m| m[:anga] }
  end

  private

  def search_anga(anga)
    searcher_for(anga).search(@query, threshold: @threshold)
  end

  def searcher_for(anga)
    file_type = Files::FileType.new(anga.filename)

    if file_type.note?
      Search::NoteSearch.new(anga)
    elsif file_type.text?
      Search::TextSearch.new(anga)
    elsif file_type.pdf?
      Search::PdfSearch.new(anga)
    elsif file_type.bookmark?
      Search::BookmarkSearch.new(anga)
    else
      Search::GenericFileSearch.new(anga)
    end
  end
end
