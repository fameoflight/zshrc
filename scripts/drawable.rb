dir = ARGV[0]

abort("no directory on #{dir}") unless Dir.exist?(dir)
    

dir_prefix = "drawable"

android_resources = "/Users/hemantv/postmates/courier-android/app/src/main/res"

Dir.foreach(dir) do | item |
    next unless item.end_with? ".png"

    resolution = item.chomp(".png").split('_').last
    new_name = item.chomp("_#{resolution}.png") + ".png"

    new_dir = "#{dir}/#{dir_prefix}-#{resolution}"

    old_path = "#{dir}/#{item}"
    new_path = "#{new_dir}/#{new_name}"
    puts "Moving #{old_path} to #{new_path}"
    Dir.mkdir(new_dir) unless Dir.exist? new_dir
    File.rename old_path, new_path
end