require 'net/http'
require 'fileutils'
require 'progressbar'

download_dir = "/tmp/Downloads/Wallpapers"
FileUtils::mkdir_p download_dir

base_url = "quotefancy.com"
base_path = "/download/%s/original/wallpaper.jpg"

def download_url(base_url, path, filename)
    # Must be somedomain.net instead of somedomain.net/, otherwise, it will throw exception.
    Net::HTTP.start(base_url) do |http|
        file_size = http.request_head(path)['content-length'].to_i
        next if file_size < 100
        # puts response['content-length']
        puts "Downloading #{filename} Size #{file_size}"
        pbar = ProgressBar.new("Progress", file_size)
        @counter = 0
        File.open(filename, "wb") do |f|
            http.get(path) do |str|
              f.write str
              @counter += str.length
              pbar.set(@counter)
            end
        end
        pbar.finish
    end
end


limit = 1500
filebar = ProgressBar.new("Progress", limit)

for i in 200..limit
    path = base_path % [i]
    filename = download_dir + "/Wallpaper #{i.to_s}.jpg"

    begin
         download_url(base_url, path, filename)
    rescue StandardError => e

    end
    filebar.set(i)
end

