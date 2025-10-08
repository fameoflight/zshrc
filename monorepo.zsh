# Helper function to find project directories
# Returns the path to project-type directory (e.g., jagora-api, jagora-web, jagora-flutter)
find-project-dir() {
  local type="$1"  # api, web, or flutter

  # Try git root first
  local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$git_root" ]]; then
    local git_basename=$(basename "$git_root")

    # Check if we're already in the target type
    if [[ "$git_basename" == *-"$type" || "$git_basename" == "$type" ]]; then
      echo "$git_root"
      return 0
    fi

    # Check if git root has the pattern (e.g., jagora-web -> look for jagora-api)
    if [[ "$git_basename" =~ ^(.+)-(api|web|flutter|mobile)$ ]]; then
      local project_name="${BASH_REMATCH[1]}"
      local project_root=$(dirname "$git_root")
      # Check for exact match first, then suffixed
      for target_dir in "$project_root/$type" "$project_root/${project_name}-${type}"; do
        if [[ -d "$target_dir" ]]; then
          echo "$target_dir"
          return 0
        fi
      done
    else
      # Git root might be parent dir (like jagora-ai), look for subdirs
      # Check for exact match 'api' first, then suffixed '*-api'
      for subdir in "$git_root/$type" "$git_root"/*-"$type"(/N); do
        if [[ -d "$subdir" ]]; then
          echo "$subdir"
          return 0
        fi
      done
    fi
  fi

  return 1
}

function code-api() {
  local api_dir=$(find-project-dir "api")
  if [[ -n "$api_dir" ]] && [[ -f "$api_dir/Gemfile" ]]; then
    echo "Found Rails project: $api_dir"
    zed "$api_dir"
    return 0
  fi

  # Fallback to original search logic if helper fails
  local start_dir="${1:-$(pwd)}"
  local dir="$start_dir"

  # Search current and parent directories for Rails projects
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/Gemfile" ]] && [[ -f "$dir/config/application.rb" ]]; then
      echo "Found Rails project: $dir"
      zed "$dir"
      cd "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  echo "No Rails projects found."
  return 1
}

function code-web() {
  local web_dir=$(find-project-dir "web")
  if [[ -n "$web_dir" ]] && [[ -f "$web_dir/package.json" ]]; then
    echo "Found web project: $web_dir"
    code "$web_dir"
    cd "$web_dir"
    return 0
  fi

  # Fallback to original search logic if helper fails
  local start_dir="${1:-$(pwd)}"
  local dir="$start_dir"

  # Search current and parent directories for web projects
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]]; then
      echo "Found web project: $dir"
      code "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  echo "No web projects found."
  return 1
}

function code-flutter() {
  local flutter_dir=$(find-project-dir "flutter")
  if [[ -n "$flutter_dir" ]] && [[ -f "$flutter_dir/pubspec.yaml" ]]; then
    echo "Found Flutter project: $flutter_dir"
    studio "$flutter_dir"
    return 0
  fi

  # Fallback to original search logic if helper fails
  local start_dir="${1:-$(pwd)}"
  local dir="$start_dir"

  # Search current and parent directories for Flutter projects
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/pubspec.yaml" ]]; then
      echo "Found Flutter project: $dir"
      studio "$dir"
      cd "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  echo "No Flutter projects found."
  return 1
}



# Simple navigation functions using the helper
function nav-api() {
  local api_dir=$(find-project-dir "api")
  if [[ -n "$api_dir" ]]; then
    cd "$api_dir"
    echo "📍 API: $api_dir"
  else
    echo "❌ Could not find API directory"
    return 1
  fi
}

function nav-web() {
  local web_dir=$(find-project-dir "web")
  if [[ -n "$web_dir" ]]; then
    cd "$web_dir"
    echo "📍 Web: $web_dir"
  else
    echo "❌ Could not find Web directory"
    return 1
  fi
}

function nav-flutter() {
  local flutter_dir=$(find-project-dir "flutter")
  if [[ -n "$flutter_dir" ]]; then
    cd "$flutter_dir"
    echo "📍 Flutter: $flutter_dir"
  else
    echo "❌ Could not find Flutter directory"
    return 1
  fi
}

# Generic project fixing/linting utilities using common helper
function fix-api() {
  local original_dir=$(pwd)
  local api_dir=$(find-project-dir "api")
  if [[ -n "$api_dir" ]] && [[ -f "$api_dir/Gemfile" ]]; then
    cd "$api_dir"
    echo "🔧 Running RuboCop auto-correction..."
    if command -v bundle >/dev/null 2>&1; then
      bundle exec rubocop --autocorrect-all
    else
      rubocop --autocorrect-all
    fi
    cd "$original_dir"
  else
    echo "❌ Could not find API directory or not a Rails project"
    return 1
  fi
}

function fix-web() {
  local original_dir=$(pwd)
  local web_dir=$(find-project-dir "web")
  if [[ -n "$web_dir" ]] && [[ -f "$web_dir/package.json" ]]; then
    cd "$web_dir"
    # Run ESLint
    echo "🔧 Running ESLint auto-fix..."
    npx eslint . --fix
    
    # Run Prettier
    echo "🎨 Running Prettier..."
    if ! npx prettier --write . 2>&1 | head -4; then
      echo "⚠️  Prettier failed - try: npm install prettier@latest"
    fi
    cd "$original_dir"
  else
    echo "❌ Could not find Web directory or not a web project"
    return 1
  fi
}

function fix-flutter() {
  local original_dir=$(pwd)
  local flutter_dir=$(find-project-dir "flutter")
  if [[ -n "$flutter_dir" ]] && [[ -f "$flutter_dir/pubspec.yaml" ]]; then
    cd "$flutter_dir"
    echo "🔧 Running Dart formatter and fixes..."
    
    if command -v dart >/dev/null 2>&1; then
      # Use dart format instead of flutter format
      dart format .
      echo "🔧 Applying Dart fixes..."
      dart fix --apply
      echo "🔧 Running Flutter analyze..."
      if command -v flutter >/dev/null 2>&1; then
        flutter analyze
      else
        echo "⚠️  Flutter CLI not found, skipping analyze"
      fi
    else
      echo "❌ Dart CLI not found"
      cd "$original_dir"
      return 1
    fi
    cd "$original_dir"
  else
    echo "❌ Could not find Flutter directory or not a Flutter project"
    return 1
  fi
}

# Universal fix function that detects project type
function fix-project() {
  # Try to fix based on current location
  if [[ -f "Gemfile" ]]; then
    fix-api
  elif [[ -f "pubspec.yaml" ]]; then
    fix-flutter  
  elif [[ -f "package.json" ]]; then
    fix-web
  else
    echo "❌ Unknown project type. Use fix-api, fix-web, or fix-flutter directly"
    return 1
  fi
}

# Fix all projects in the monorepo
function fix-all() {
  local has_errors=0
  local fixed_projects=()
  
  echo "🔧 Running fixes across all monorepo projects..."
  echo
  
  # Try to fix API project
  local api_dir=$(find-project-dir "api")
  if [[ -n "$api_dir" ]] && [[ -f "$api_dir/Gemfile" ]]; then
    echo "🚀 Fixing API project..."
    if fix-api; then
      fixed_projects+=("✅ API")
    else
      fixed_projects+=("❌ API (failed)")
      has_errors=1
    fi
    echo
  fi
  
  # Try to fix Web project  
  local web_dir=$(find-project-dir "web")
  if [[ -n "$web_dir" ]] && [[ -f "$web_dir/package.json" ]]; then
    echo "🚀 Fixing Web project..."
    if fix-web; then
      fixed_projects+=("✅ Web")
    else
      fixed_projects+=("❌ Web (failed)")
      has_errors=1
    fi
    echo
  fi
  
  # Try to fix Flutter project
  local flutter_dir=$(find-project-dir "flutter")
  if [[ -n "$flutter_dir" ]] && [[ -f "$flutter_dir/pubspec.yaml" ]]; then
    echo "🚀 Fixing Flutter project..."
    if fix-flutter; then
      fixed_projects+=("✅ Flutter")
    else
      fixed_projects+=("❌ Flutter (failed)")
      has_errors=1
    fi
    echo
  fi
  
  # Summary
  if [[ ${#fixed_projects[@]} -eq 0 ]]; then
    echo "⚠️  No projects found to fix"
    return 1
  else
    echo "📋 Fix Summary:"
    printf '%s\n' "${fixed_projects[@]}"
    echo
    if [[ $has_errors -eq 0 ]]; then
      echo "🎉 All projects fixed successfully!"
    else
      echo "⚠️  Some projects had errors - check output above"
      return 1
    fi
  fi
}

function railway-shell() {
  local api_dir=$(find-project-dir "api")
  if [[ -n "$api_dir" ]] && [[ -f "$api_dir/Gemfile" ]]; then
    echo "Found Rails project: $api_dir"
    cd "$api_dir"
    
    if command -v railway >/dev/null 2>&1; then
      railway run rails c
    else
      echo "❌ Railway CLI not found"
      return 1
    fi
    return 0
  fi
  echo "❌ No Rails project found"
  return 1
}

# Debug function to troubleshoot directory finding
function debug-find-flutter() {
  echo "=== Debug Flutter Directory Finding ==="
  local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  echo "Git root: $git_root"
  if [[ -n "$git_root" ]]; then
    echo "Git basename: $(basename "$git_root")"
    echo "Looking for Flutter directories..."
    ls -la "$git_root" | grep -E "(flutter|mobile)"
    echo "Checking for pubspec.yaml files:"
    find "$git_root" -name "pubspec.yaml" -type f 2>/dev/null
  fi
  echo "find-project-dir result: $(find-project-dir "flutter")"
}

# # Auto-setup command aliases when in monorepo
# function setup_monorepo_aliases() {
#   local api_dir=$(find-project-dir "api" 2>/dev/null)
#   local web_dir=$(find-project-dir "web" 2>/dev/null)
#   local flutter_dir=$(find-project-dir "flutter" 2>/dev/null)
  
#   # Debug output
#   # echo "Debug: api_dir=$api_dir, web_dir=$web_dir, flutter_dir=$flutter_dir"
  
#   # Rails/API commands
#   if [[ -n "$api_dir" ]] && [[ -f "$api_dir/Gemfile" ]]; then
#     function rails() {
#       command rails -C "$api_dir" "$@" 2>/dev/null || (cd "$api_dir" && command rails "$@")
#     }
#     function rake() {
#       command rake -f "$api_dir/Rakefile" "$@" 2>/dev/null || (cd "$api_dir" && command rake "$@")
#     }
#     function bundle() {
#       command bundle --gemfile="$api_dir/Gemfile" "$@" 2>/dev/null || (cd "$api_dir" && command bundle "$@")
#     }
#     function rspec() {
#       (cd "$api_dir" && command rspec "$@")
#     }
#   else
#     unfunction rails 2>/dev/null || true
#     unfunction rake 2>/dev/null || true
#     unfunction bundle 2>/dev/null || true
#     unfunction rspec 2>/dev/null || true
#   fi
  
#   # Web/Node commands
#   if [[ -n "$web_dir" ]] && [[ -f "$web_dir/package.json" ]]; then
#     function yarn() {
#       pushd "$web_dir" >/dev/null
#       command yarn "$@"
#       popd >/dev/null
#       # Clean up unwanted files created in parent workspace
#       rm -f node_modules
#       rm -f yarn.lock
#     }
#     function npm() {
#       pushd "$web_dir" >/dev/null
#       command npm "$@"
#       popd >/dev/null
#     }
#     function npx() {
#       pushd "$web_dir" >/dev/null
#       command npx "$@"
#       popd >/dev/null
#     }
#     function node() {
#       pushd "$web_dir" >/dev/null
#       command node "$@"
#       popd >/dev/null
#     }
#   else
#     unfunction yarn 2>/dev/null || true
#     unfunction npm 2>/dev/null || true
#     unfunction npx 2>/dev/null || true
#     unfunction node 2>/dev/null || true
#   fi
  
#   # Flutter commands
#   if [[ -n "$flutter_dir" ]] && [[ -f "$flutter_dir/pubspec.yaml" ]]; then
#     function flutter() {
#       local current_flutter_dir=$(find-project-dir "flutter" 2>/dev/null)
#       if [[ -n "$current_flutter_dir" ]] && [[ -d "$current_flutter_dir" ]] && pushd "$current_flutter_dir" >/dev/null 2>&1; then
#         command flutter "$@"
#         local exit_code=$?
#         popd >/dev/null
#         return $exit_code
#       else
#         echo "Error: Could not change to Flutter directory: $current_flutter_dir"
#         return 1
#       fi
#     }
#     function dart() {
#       local current_flutter_dir=$(find-project-dir "flutter" 2>/dev/null)
#       if [[ -n "$current_flutter_dir" ]] && [[ -d "$current_flutter_dir" ]] && pushd "$current_flutter_dir" >/dev/null 2>&1; then
#         command dart "$@"
#         local exit_code=$?
#         popd >/dev/null
#         return $exit_code
#       else
#         echo "Error: Could not change to Flutter directory: $current_flutter_dir"
#         return 1
#       fi
#     }
#     function pub() {
#       local current_flutter_dir=$(find-project-dir "flutter" 2>/dev/null)
#       if [[ -n "$current_flutter_dir" ]] && [[ -d "$current_flutter_dir" ]] && pushd "$current_flutter_dir" >/dev/null 2>&1; then
#         command dart pub "$@"
#         local exit_code=$?
#         popd >/dev/null
#         return $exit_code
#       else
#         echo "Error: Could not change to Flutter directory: $current_flutter_dir"
#         return 1
#       fi
#     }
#   else
#     unfunction flutter 2>/dev/null || true
#     unfunction dart 2>/dev/null || true
#     unfunction pub 2>/dev/null || true
#   fi
# }

# # Auto-setup when changing directories
# function chpwd() {
#   setup_monorepo_aliases
# }

# # Setup on shell startup if already in monorepo
# setup_monorepo_aliases
