# frozen_string_literal: true

require_relative '../script_base'

# Concern for managing accounts
module AccountManager
  CREDENTIALS_PATH = File.join(ScriptBase::PROJECT_ROOT, 'credentials', 'gmail.json')
  TOKEN_DIR = File.join(ScriptBase::PROJECT_ROOT, 'credentials', 'tokens')
  CACHE_DIR = File.join(ScriptBase::PROJECT_ROOT, 'credentials', 'cache')

  def select_account
    return if @account_name

    existing_accounts = Dir.glob(File.join(TOKEN_DIR, '*.yaml')).map { |f| File.basename(f, '.yaml') }

    if existing_accounts.empty?
      log_info 'No existing accounts found.'
      new_account_name = ask_string('Enter a name for your new account:')
      if confirm_action("Create new account '#{new_account_name}'?")
        @account_name = new_account_name
      else
        exit_with_message('Account creation cancelled.')
      end
    else
      choices = existing_accounts + ['[Create a new account]', '[Delete an account]']
      selection = ask_choice('Select an account:', choices)

      if selection == '[Create a new account]'
        new_account_name = ask_string('Enter a name for your new account:')
        if confirm_action("Create new account '#{new_account_name}'?")
          @account_name = new_account_name
        else
          exit_with_message('Account creation cancelled.')
        end
      elsif selection == '[Delete an account]'
        delete_account(existing_accounts)
        # After deletion, restart account selection
        select_account
      else
        @account_name = selection
      end
    end
    log_info "Using account: #{@account_name}"
  end

  def delete_account(existing_accounts)
    account_to_delete = ask_choice('Which account do you want to delete?', existing_accounts)

    if confirm_action("⚠️  Delete account '#{account_to_delete}' and all its data?")
      # Delete token file
      token_file = File.join(TOKEN_DIR, "#{account_to_delete}.yaml")
      File.delete(token_file) if File.exist?(token_file)

      # Delete cache file
      cache_file = File.join(CACHE_DIR, "#{account_to_delete}.sqlite.db")
      File.delete(cache_file) if File.exist?(cache_file)

      log_success("🗑️ Account '#{account_to_delete}' has been deleted")

      # Check if there are any accounts left
      remaining_accounts = Dir.glob(File.join(TOKEN_DIR, '*.yaml')).map { |f| File.basename(f, '.yaml') }
      log_info("No accounts remaining. You'll need to create a new one.") if remaining_accounts.empty?
    else
      log_info('Account deletion cancelled.')
    end
  end

  def token_path
    File.join(TOKEN_DIR, "#{@account_name}.yaml")
  end

  def cache_path
    File.join(CACHE_DIR, "#{@account_name}.sqlite.db")
  end
end
