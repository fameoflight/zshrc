alias routes="bundle exec rails routes"

alias migrate="rails db:migrate && rails db:migrate RAILS_ENV=test"
alias rollback="rails db:rollback && rails db:rollback RAILS_ENV=test"

alias migrate-data="rails db:migrate:with_data && rails db:migrate:with_data RAILS_ENV=test"
alias rollback-data="rails db:rollback:with_data && rails db:rollback:with_data RAILS_ENV=test"


# function autofix() {  
#   files=`git diff --stat HEAD..master --name-only`

#   for file in $files; do
#     bundle exec rubocop $file
#   done
# }
alias autofix="bundle exec rubocop --autocorrect-all"

function autofix-modified() {
  # only modify files that have been modified
  git ls-files -m | xargs ls -1 2>/dev/null | grep '\.rb$' | xargs bundle exec rubocop --autocorrect-all
}

function autofix-branch() {
  # only on files different from master
  git diff-tree -r --no-commit-id --name-only head origin/master | xargs bundle exec rubocop --autocorrect-all
}

function rspec-modified() {
  # only run tests on files that have been modified
  echo "Running tests on modified files"
  echo "-----------------------------"

  echo "Modified files:"

  git ls-files -m | xargs ls -1 2>/dev/null | grep '\.rb$' | xargs bundle exec rubocop --autocorrect-all

  rspec $(git ls-files --modified --others spec)
}

