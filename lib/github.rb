require 'json'
require 'timeout'

class Github
  TimeoutError = Class.new(Timeout::Error)
  TIMEOUT = 10

  TOKEN_PATH = File.expand_path('~/.githubreview')

  class Comment
    attr_reader :author, :body, :created_at
    def initialize(hash)
      @author = hash['user']['login']
      @body = hash['body']
      @created_at = hash['created_at']
    end

    def to_s
      "@#{author}\n#{'-' * (author.length + 1)}\n#{body}"
    end
  end

  def initialize(pull_request_url)
    @url = pull_request_url
  end

  def get_comments
    user, repo, pull = url_info
    @comments_path ||= Tempfile.new("review-#{user}-#{repo}-#{pull}-comments.json").path
    curl %(-H "Accept: application/json" #{base_api_url(true)}/comments -o #{@comments_path})
    JSON.load(File.read(@comments_path)).map(&Comment.method(:new))
  end

  def post_change_comment(contents, location)
    body = JSON.dump(body: contents,
                     commit_id: location.commit_id,
                     path: location.path,
                     position: location.position)

    curl %(-X POST -H "Accept: application/json" -H "Content-type: application/json" #{base_api_url}/comments -d '#{body}')
    :OK
  end

  def post_comment(contents)
    body = JSON.dump(body: contents)

    curl %(-X POST -H "Accept: application/json" -H "Content-type: application/json" #{base_api_url(true)}/comments -d '#{body}')
    :OK
  end

  def patch_path
    @patch_path ||= download_pull_request('application/vnd.github.v3.patch')
  end

  def pull_request_data
    @pull_request_data ||= begin
      path = download_pull_request('application/json')
      data = JSON.parse(File.read(path))
      {
        head: data['head']['sha'],
        base: data['base']['sha'],
        merged: data['merged'],
        body: data['body']
      }
    end
  end

  def diff_path
    @diff_path ||= download_pull_request('application/vnd.github.v3.diff')
  end

  def create_review(review)
    body = JSON.dump(body: review.body,
                     event: review.event,
                     comments: review.comments.map(&:to_h))

    review = JSON.parse(
      curl(
        %(-X POST -H "Accept: application/json" -H "Content-type: application/json" #{base_api_url}/reviews -d '#{body}')
      )
    )
    { id: review['id'] }
  end

  private

  attr_reader :url

  def token
    @token ||= begin
      if File.exist?(TOKEN_PATH)
        File.read(TOKEN_PATH)
      else
        token = Vim.evaluate("input('Create a GitHub authorization token and paste it here: ')")
        File.open(TOKEN_PATH, 'w') do |file|
          file.write token
        end
        token
      end
    end
  end

  def download_pull_request(content_type)
    user, repo, pull = url_info
    temp = Tempfile.new("review-#{user}-#{repo}-#{pull}.patch")
    puts "Downloading Pull Request #{user}/#{repo}##{pull}..."
    curl %(-H "Accept: #{content_type}" -L -o #{temp.path} #{base_api_url})
    temp.path
  end

  def url_info
    url.scan(/github\.com\/(.*)\/(.*)\/pull\/(\d+)/).first
  end

  def base_api_url(issue = false)
    user, repo, pull = url_info
    "https://api.github.com/repos/#{user}/#{repo}/#{issue ? 'issues' : 'pulls'}/#{pull}"
  end

  def curl(args)
    Timeout.timeout(TIMEOUT) { `curl --silent -H "Authorization: token #{token}" #{args}` }
  rescue Timeout::Error => e
    raise TimeoutError, e.message
  end
end
