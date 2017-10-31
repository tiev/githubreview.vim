require 'tempfile'
require 'json'
require_relative 'diff'
require_relative 'github'
require_relative 'review'
require_relative 'vim_ext'

class GithubReview
  class << self
    attr_reader :current
  end

  def self.review(url)
    @current = new(url)
    @current.review
  end

  def initialize(url)
    @github = Github.new(url)
    @review_obj = Review.new
  end

  def review
    `git stash --include-untracked; git checkout #{pull_request_data[:base]}`
    Vim.command "DiffReview cat #{diff_path}"
    Vim.command 'file Overview'
    Vim.command 'setlocal buftype=nofile'
    reload_comments
  end

  def reload_comments
    Vim.command 'tabfirst'
    Vim.command 'tabnext' until VIM::Buffer.current == overview_buffer
    Vim.command '%d'
    (
      [
        'DESCRIPTION', '',
        pull_request_data[:body].gsub("\r\n", "\n").split("\n"), '',
        'PULL REQUEST COMMENTS', ''
      ].flatten +
     render_comments.split("\n")
    ).each_with_index do |line, idx|
      overview_buffer.append(idx, line)
    end
  end

  def edit_summary
    Vim.command 'vsplit Edit_Summary'
    Vim.command 'normal! ggdG'
    Vim.command 'setlocal buftype=nofile'
    Vim.command 'silent nnoremap <buffer> <leader>c :ruby GithubReview.current.update_summary<cr>'
    Vim.command %{echo "Write your Review Summary in this window, then type <leader>c when you're done. And be constructive! :)"}
  end

  def update_summary
    buf = VIM::Buffer.current
    contents = Array.new(buf.count) { |i| buf[i + 1] }.join("\n")
    review_obj.body = contents
    Vim.command 'bd'
    Vim.command %(echo "Review Summary updated.")
  end

  def submit
    Vim.command %(let review_event = confirm("Choose review type:", "&Comment\n&Approve\n&Request changes", 1))
    review_obj.event = case Vim.evaluate('review_event')
                       when 2
                         Review::EVENT_APPROVE
                       when 3
                         Review::EVENT_REQUEST_CHANGE
                       else
                         Review::EVENT_COMMENT
                       end
    Vim.command %(echo "Submitting code review to Github...")
    result = github.create_review(review_obj)
    Vim.command %(echo "Code Review submitted. ID=#{result[:id]}")
  end

  def new_comment
    contents = File.read(diff_path)

    win0 = VIM::Window[0]
    win1 = VIM::Window[1]
    win2 = VIM::Window[2]

    names = [win0.buffer.name, win1.buffer.name]
    current_file = VIM::Buffer.current.name.empty? ? :patched : :original
    if win2
      names.push(win2.buffer.name)
      current_file = :diff if VIM::Window.current == win0
    end

    filename = names.find { |name| !name.empty? }
                    .gsub(Vim.evaluate('getcwd()') + '/', '')

    line_number = VIM::Buffer.current.line_number
    text = VIM::Buffer.current[line_number].chomp

    Vim.command %(echo "#{current_file}>#{filename}:#{line_number} #{text}")
    diff = Diff.new(contents)
    Vim.command %(echo "====")
    @location = if current_file == :original
                  diff.find_deletion(filename, line_number, text)
                elsif current_file == :patched
                  diff.find_addition(filename, line_number, text)
                else
                  diff.find_in_diff(filename, line_number-2, text)
                end

    Vim.command 'vsplit New_Review_Comment'
    Vim.command 'normal! ggdG'
    Vim.command 'setlocal buftype=nofile'
    Vim.command 'silent nnoremap <buffer> <leader>c :ruby GithubReview.current.create_comment<cr>'
    Vim.command %{echo "Write your comment in this window, then type <leader>c when you're done. And be constructive! :)"}
  end

  def create_comment
    unless @location
      raise ArgumentError, "Can't create a comment from a non-comment buffer. Call :GithubReviewComment first."
    end

    buf = VIM::Buffer.current
    contents = Array.new(buf.count) { |i| buf[i + 1] }.join("\n")
    review_obj.comments.push(
      Review::Comment.new(
        path: @location.path,
        position: @location.position,
        body: contents
      )
    )
    Vim.command 'bd'
    Vim.command %(echo "Comment added.")
  end

  private

  attr_reader :github, :review_obj

  def overview_buffer
    @overview_buffer ||=
      begin
        idx = VIM::Buffer.count.times.detect do |i|
          VIM::Buffer[i].name =~ /Overview$/
        end
        raise("Can't find Overview buffer -- did you close it?") unless idx
        VIM::Buffer[idx]
      end
  end

  def render_comments
    github.get_comments.map(&:to_s).join("\n\n")
  end

  def diff_path
    github.diff_path
  end

  def pull_request_data
    github.pull_request_data
  end
end
