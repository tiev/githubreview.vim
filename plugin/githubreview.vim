if !exists('g:GITHUBREVIEW_INSTALL_PATH')
  let g:GITHUBREVIEW_INSTALL_PATH = fnamemodify(expand("<sfile>"), ":p:h")
end

command! -nargs=1 GithubReview call githubreview#GithubReview(<f-args>)
command! GithubReviewEditSummary call githubreview#GithubReviewSummary()
command! GithubReviewSubmit call githubreview#GithubReviewSubmit()
command! GithubReviewComment call githubreview#GithubReviewComment()
