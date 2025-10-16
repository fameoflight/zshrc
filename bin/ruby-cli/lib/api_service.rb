# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Abstract API service module for HTTP requests
# Provides base functionality for API clients
module ApiService
  def self.get(url, headers = {})
    make_request(:get, url, nil, headers)
  end

  def self.post(url, body = nil, headers = {})
    make_request(:post, url, body, headers)
  end

  def self.put(url, body = nil, headers = {})
    make_request(:put, url, body, headers)
  end

  def self.delete(url, headers = {})
    make_request(:delete, url, nil, headers)
  end

  def self.patch(url, body = nil, headers = {})
    make_request(:patch, url, body, headers)
  end

  private

  def self.make_request(method, url, body = nil, headers = {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30
    http.open_timeout = 10

    request_class = case method.to_sym
                   when :get
                     Net::HTTP::Get
                   when :post
                     Net::HTTP::Post
                   when :put
                     Net::HTTP::Put
                   when :delete
                     Net::HTTP::Delete
                   when :patch
                     Net::HTTP::Patch
                   else
                     raise ArgumentError, "Unsupported HTTP method: #{method}"
                   end

    request = request_class.new(uri.request_uri)
    request.body = body if body

    headers.each { |key, value| request[key] = value }

    response = http.request(request)
    response
  rescue StandardError => e
    puts "Request failed: #{e.message}"
    nil
  end

  def self.parse_json(response)
    return nil unless response

    begin
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      puts "Failed to parse JSON: #{e.message}"
      nil
    end
  end
end