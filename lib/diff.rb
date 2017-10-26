require_relative 'diff/file_diff'

class Diff
  ProcessingError = Class.new(StandardError)
  Location = Struct.new(:path, :position)

  def initialize(diff)
    @diff = diff
  end

  def find_addition(filename, subjective_line, text)
    find_change(filename, subjective_line, :+, text)
  end

  def find_deletion(filename, subjective_line, text)
    find_change(filename, subjective_line, :-, text)
  end

  def find_in_diff(filename, subjective_line, text)
    file_diffs
      .select { |file_diff| file_diff.filename == filename }
      .reverse
      .each do |file_diff|
        location = file_diff.find_in_diff(subjective_line, text)
        return location if location
      end
    raise ProcessingError, "Couldn't find that line in the diff. Remember that you can only comment on additions or deletions."
  end

  def find_change(filename, subjective_line, kind, text)
    file_diffs
      .select { |file_diff| file_diff.filename == filename }
      .reverse
      .each do |file_diff|
        location = file_diff.find_change(subjective_line, kind, text)
        return location if location
      end
    raise ProcessingError, "Couldn't find that line in the diff. Remember that you can only comment on additions or deletions."
  end

  private

  def file_diffs
    @file_diffs ||= FileDiff.from_diff(@diff)
  end
end
