# Rails-specific aliases and utilities
# For more advanced project management, see monorepo.zsh

# Database utilities
alias routes="bundle exec rails routes"
alias migrate="rails db:migrate && rails db:migrate RAILS_ENV=test"
alias rollback="rails db:rollback && rails db:rollback RAILS_ENV=test"
alias migrate-data="rails db:migrate:with_data && rails db:migrate:with_data RAILS_ENV=test"  
alias rollback-data="rails db:rollback:with_data && rails db:rollback:with_data RAILS_ENV=test"

# Enhanced test runner with fixing
function rspec-modified() {
  echo "🧪 Running tests on modified files"
  echo "=================================="

  # First fix the modified files
  local modified_files=$(git ls-files -m | grep '\.rb$')
  if [[ -n "$modified_files" ]]; then
    echo "🔧 Auto-fixing modified Ruby files first..."
    echo "$modified_files" | xargs bundle exec rubocop --autocorrect-all
  fi

  # Run tests on modified spec files
  local spec_files=$(git ls-files --modified --others spec | grep '_spec\.rb$')
  if [[ -n "$spec_files" ]]; then
    echo "🧪 Running specs for modified files..."
    rspec $spec_files
  else
    echo "📝 No modified spec files found"
  fi
}

# Test utilities
function rspec-failed() {
  echo "🔄 Re-running failed specs..."
  rspec --only-failures
}

function rspec-coverage() {
  echo "📊 Running specs with coverage..."
  COVERAGE=true rspec
}

