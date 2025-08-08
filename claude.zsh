function claude() {

  # check if /opt/homebrew/bin/claude exists 
  # warn that this need to renamed to claude-code

  # if [[ -f /opt/homebrew/bin/claude ]]; then
  #   echo "Error: /opt/homebrew/bin/claude exists, consider renaming it to claude-code."

  #   return 1
  # fi

  # check if claude-code exists
  if [[ -f /opt/homebrew/bin/claude-code ]]; then

    # make sure this is code repository using git rev-parse --show-toplevel
    # claude can only be executed in subdirectory of a git repository
    if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
      echo "Error: claude can only be executed in a git repository."
      return 1
    fi

    # go to the root of the git repository
    cd `git rev-parse --show-toplevel` || return 1

    # make sure Claude.md or CLAUDE.md exists
    if [[ ! -f CLAUDE.md ]]; then
      echo "Warning: Claude.md or CLAUDE.md does not exist in the root of the git repository."
    fi

    # make sure 
    echo "Running claude-code in: `pwd`"
    /opt/homebrew/bin/claude-code "$@"
  else
    echo "Error: /opt/homebrew/bin/claude-code does not exist."

    echo "Please install claude-code from https://www.anthropic.com/claude-code"

    echo "Or rename /opt/homebrew/bin/claude to claude-code if it exists."
    return 1
  fi
}