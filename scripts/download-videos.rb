require 'net/http'
require 'fileutils'
require 'progressbar'

download_dir = "/Users/hemantverma/Downloads/Mahadev"
FileUtils::mkdir_p download_dir

base_url = "media.startv.in"
base_path = "/newstream/star/lifeok/mahadev/%s/lf_300.mp4"

def download_url(base_url, path, filename)
    # Must be somedomain.net instead of somedomain.net/, otherwise, it will throw exception.
    Net::HTTP.start(base_url) do |http|
        file_size = http.request_head(path)['content-length'].to_i
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


for i in 822..1000
    path = base_path % [i]
    filename = download_dir + "/Episode #{i.to_s.rjust(4, "0")}.mp4"
    # puts filename, path
    download_url(base_url, path, filename)
end

