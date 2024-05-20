require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'progressbar'
require 'set'
require 'uri'

def get_quotes_url(url)
  doc = Nokogiri::HTML(open(url))
  links = doc.xpath('//a[@href]').select  { |link| link.text.end_with? 'Quotes' }
  links.map {|link| link['href'] }
end


def n_level_deep(root_url, level)
  urls = [root_url]
  for idx in 0..level
    puts "Running for Level #{idx}"

    new_urls = urls
    pbar = ProgressBar.new("Level #{idx} #{urls.length}", urls.length)
    urls.each_with_index do |url, index|
      new_urls += get_quotes_url(url)
      pbar.set(index+1)
    end
    new_urls.compact!
    new_urls.uniq!
    break if new_urls.length == urls

    urls = new_urls.uniq
  end

  urls
end

urls = n_level_deep('http://quotefancy.com/', 5)

def get_image_urls(url)
  doc = Nokogiri::HTML(open(url))
  image_urls = doc.css('a').map { |e| e['href'] }.compact
  image_urls.reject! {|image_url| !image_url.include? "download" }

  image_urls.map! do |image_url|
    image_url = "#{url}#{image_url}" unless image_url.include? url
  end
end


wallpapers = []
pbar = ProgressBar.new("Finding Images #{urls.length}", urls.length)
urls.each_with_index do |url, index|
  wallpapers += get_image_urls(url)
  pbar.set(index + 1)
end
wallpapers.uniq!

File.open("wallpaper-urls.txt", "w") do |file|
  file << wallpapers.join("\n")
end








