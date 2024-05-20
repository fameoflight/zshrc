require "mp3info"

dir = "/Users/hemantv/Downloads/Headspace/Headspace Extra"

def get_mp3_file_paths(path)
  file_number = lambda { |f| f.chomp(".mp3").split("-")[-1].to_i }
  course_name = lambda { |f| f.split("/")[-2].strip }
  mp3_files = Dir.glob(path + '/**/*.mp3')
  # mp3_files = mp3_files.sort do | a, b |
  #   file_number.call(a) <=> file_number.call(b) if course_name.call(a) == course_name.call(b)
  #   course_name.call(a) <=> course_name.call(b)
  # end

  mp3_files.each do |f|
    yield f
  end
end

previous_course_name = nil
tracknum = 0

get_mp3_file_paths(dir) do | file_path |
  series = file_path.split("/")[-3].strip
  course_name = file_path.split("/")[-2].chomp("Headspace").strip
  if course_name != previous_course_name
    tracknum = 1
  else
    tracknum += 1
  end

  # title = "Track #{tracknum}"
  title = file_path.split("/")[-1].strip.chomp(".mp3")

  # puts "#{series} #{course_name}, #{title},  #{tracknum}"
  puts "#{course_name}, #{title},  #{tracknum}"

  Mp3Info.open(file_path) do |mp3|
    # mp3.tag.tracknum = tracknum
    # mp3.tag.title = title
    # mp3.tag.artist = "Headspace"
    # mp3.tag.genre_s = "Audio Book"
    # mp3.tag.album = "Headspace #{course_name}"
  end

  previous_course_name = course_name
end
