class Diff
  class FileDiff
    class Hunk
      def initialize(offset, line, body)
        @offset = offset
        @line = line
        @lines = body.each_line.to_a
      end

      def find_change(subjective_line, kind, text)
        index = subjective_line - @line
        while @lines[index] && @lines[index].chomp != "#{kind}#{text}".chomp
          index += 1
        end
        return @offset + index if @lines[index]
      end
    end

    def self.from_diff(diff)
      diff
        .split(/^diff --git /).drop(1)
        .map do |raw_file_diff|
          filename = raw_file_diff.scan(/^a\/(.*) b\/.*$/).first.first
          body = raw_file_diff.split(/--- .*\n\+\+\+ .*\n/).drop(1).first.chomp
          new(filename, body)
        end
    end

    attr_reader :filename

    def initialize(filename, body)
      @filename = filename
      @body = body
      @hunks = body.split('@@ -').drop(1).map do |raw_hunk|
        header = raw_hunk.split("\n").first
        offset = body.split("\n").index("@@ -#{header}")
        line = raw_hunk.scan(/^(\d+),\d+ \+(\d+),/).first.map(&:to_i).max
        Hunk.new(offset, line, '@@ -' + raw_hunk)
      end
    end

    def find_change(subjective_line, kind, text)
      @hunks.each do |hunk|
        hunk_offset = hunk.find_change(subjective_line, kind, text)
        return Location.new(@filename, hunk_offset) if hunk_offset
      end
      nil
    end

    def find_in_diff(subjective_line, text)
      index = subjective_line - 1
      lines = @body.each_line.to_a
      index += 1 while lines[index] && lines[index].chomp != text.chomp
      Location.new(@filename, index) if lines[index]
    end
  end
end
