#!/usr/bin/env ruby
I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = nil


require 'rubygems'
require 'mechanize'

URL_PRELOADER = 'https://customer.comcast.com/Secure/Preload.aspx?backTo=%2fSecure%2fUsers.aspx&preload=true'
URL_USERS = 'https://customer.comcast.com/Secure/Users.aspx'
URL_ACCOUNT = 'https://customer.comcast.com/Secure/Account.aspx'


OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE


abort "Usage: #{$0} <username> <password>" unless ARGV.length == 2

agent = Mechanize.new

agent = Mechanize.new { |agent|
  agent.follow_meta_refresh = true
  agent.redirect_ok = true
  agent.user_agent = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6'
}

login_page = agent.get("https://login.xfinity.com/login?r=comcast.net&s=oauth&continue=https%3A%2F%2Foauth.xfinity.com%2Foauth%2Fauthorize%3Fclient_id%3Dmy-account-web%26prompt%3Dlogin%26redirect_uri%3Dhttps%253A%252F%252Fcustomer.xfinity.com%252Foauth%252Fcallback%26response_type%3Dcode%26state%3Dhttps%253A%252F%252Fcustomer.xfinity.com%252Fusers%252F%26response%3D1&forceAuthn=1&client_id=my-account-web&reqId=b941e0c3-e7f7-4dd5-a6f5-f32a6dcf6cf8")


# login_form = login_page.form_with(:name => 'signin')
# login_form.user = ARGV[0]
# login_form.passwd = ARGV[1]

# redirect_page = agent.submit(login_form)
# redirect_form = redirect_page.form_with(:name => 'redir')

# abort 'Error: Login failed' unless redirect_form

# account_page = agent.submit(redirect_form, redirect_form.buttons.first)

# agent.get(URL_PRELOADER)
# users_page = agent.get(URL_USERS)
# usage_text = users_page.search(".usage-graph-legend").text

# puts usage_text.strip

# users_page = agent.get(URL_ACCOUNT)
# date_range = users_page.search('//h3').select { |tag| tag.text =~ /Current Bill/ }.first

# date_range_text = date_range.search('//small').text

# puts date_range_text.strip