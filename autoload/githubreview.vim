if has('ruby')
  ruby $: << File.expand_path(File.join(Vim.evaluate('g:GITHUBREVIEW_INSTALL_PATH'), '..', 'lib'))
  ruby require 'github_review'

  fun! githubreview#GithubReview(url)
    ruby GithubReview.review Vim.evaluate("a:url")
  endfun
  fun! githubreview#GithubReviewSummary()
    ruby GithubReview.current.edit_summary
  endfun
  fun! githubreview#GithubReviewSubmit()
    ruby GithubReview.current.submit()
  endfun
  fun! githubreview#GithubReviewComment()
    ruby GithubReview.current.new_comment()
  endfun
else
  fun! githubreview#Review()
    echo "Sorry, githubreview.vim requires vim to be built with Ruby support."
  endfun

  fun! githubreview#Comment()
    echo "Sorry, githubreview.vim requires vim to be built with Ruby support."
  endfun
endif
