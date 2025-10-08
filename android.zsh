alias android-studio="open /Applications/Android\ Studio.app"
export ANDROID_HOME=/Users/hemantv/Library/Android/sdk
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/tools"

export KEYSTORE=~/Dropbox/Mackup/Android/android_playstore_release.keystore


function studio() {
  local project_path="${1:-.}"

  # Resolve to absolute path
  project_path=$(realpath "$project_path" 2>/dev/null || echo "$project_path")

  if [[ ! -d "$project_path" ]]; then
    echo "Error: Directory '$project_path' does not exist."
    return 1
  fi

  echo "Opening '$project_path' in Android Studio..."
  open -a "Android Studio" "$project_path"
}


function flutter-studio() {
  local start_dir="${1:-$(pwd)}"
  local dir="$start_dir"

  # Set nullglob option to handle empty glob patterns gracefully
  local old_nullglob_setting=$(setopt | grep nullglob || echo "off")
  setopt nullglob

  # First check if we're in a monorepo structure with Flutter projects
  local current_dir="$start_dir"
  while [[ "$current_dir" != "/" ]]; do
    # Look for Flutter projects ending with -flutter
    local flutter_candidates=("$current_dir"/*-flutter)
    
    for flutter_candidate in "${flutter_candidates[@]}"; do
      if [[ -d "$flutter_candidate" ]] && [[ -f "$flutter_candidate/pubspec.yaml" ]]; then
        echo "Found Flutter project: $flutter_candidate"
        # Restore original nullglob setting
        [[ "$old_nullglob_setting" == "off" ]] && unsetopt nullglob
        studio "$flutter_candidate"
        return 0
      fi
    done
    
    current_dir=$(dirname "$current_dir")
  done

  # Restore original nullglob setting
  [[ "$old_nullglob_setting" == "off" ]] && unsetopt nullglob

  # Search current and parent directories for Flutter projects
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/pubspec.yaml" ]] || [[ "$dir" == *-flutter ]]; then
      echo "Found Flutter project: $dir"
      studio "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  # Search sibling directories for Flutter projects (useful in monorepos)
  if [[ "$start_dir" != "/" ]]; then
    local parent_dir=$(dirname "$start_dir")
    echo "Searching sibling directories for Flutter projects..."
    
    for sibling in "$parent_dir"/*flutter* "$parent_dir"/*-flutter; do
      if [[ -d "$sibling" ]] && [[ -f "$sibling/pubspec.yaml" ]]; then
        echo "Found Flutter project: $sibling"
        studio "$sibling"
        return 0
      fi
    done
  fi

  # Search subdirectories for Flutter projects with timeout and exclusions
  echo "Searching subdirectories for Flutter projects..."
  local flutter_dirs=()

  # Use timeout and exclude common directories that cause issues
  local search_result
  search_result=$(timeout 10s find "$start_dir" \
    -maxdepth 3 \
    -type d \( -name node_modules -o -name .git -o -name build -o -name .dart_tool \) -prune -o \
    -name "pubspec.yaml" -type f -print 2>/dev/null | head -10)

  if [[ $? -eq 124 ]]; then
    echo "Search timed out. Trying manual approach..."
    # Fallback: look for common Flutter directory patterns
    for subdir in "$start_dir"/*flutter* "$start_dir"/*/; do
      if [[ -f "$subdir/pubspec.yaml" ]]; then
        flutter_dirs+=("$(dirname "$subdir/pubspec.yaml")")
      fi
    done
  else
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        flutter_dirs+=("$(dirname "$line")")
      fi
    done <<< "$search_result"
  fi

  # Remove duplicates
  flutter_dirs=($(printf '%s\n' "${flutter_dirs[@]}" | sort -u))

  if [[ ${#flutter_dirs[@]} -eq 0 ]]; then
    echo "No Flutter projects found."
    return 1
  elif [[ ${#flutter_dirs[@]} -eq 1 ]]; then
    echo "Found Flutter project: ${flutter_dirs[0]}"
    studio "${flutter_dirs[0]}"
    return 0
  else
    echo "Multiple Flutter projects found:"
    for i in "${!flutter_dirs[@]}"; do
      echo "$((i+1)). ${flutter_dirs[i]}"
    done
    read -p "Select project (1-${#flutter_dirs[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#flutter_dirs[@]} ]]; then
      studio "${flutter_dirs[$((choice-1))]}"
      return 0
    else
      echo "Invalid selection."
      return 1
    fi
  fi

  # Restore original nullglob setting at the end
  [[ "$old_nullglob_setting" == "off" ]] && unsetopt nullglob
}
