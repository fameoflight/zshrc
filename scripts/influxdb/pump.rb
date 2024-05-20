require 'influxdb'
require 'msgpack'
require 'pp'

database = 'test_db'
username = 'root'
password = 'root'
host ="influxdb.postmates.com"

$influxdb = InfluxDB::Client.new database, :host => host,
                :username => username, :password => password

DIR='/Users/hemantverma/influxdb-pump/blueox/20141017/'

$full_name_map = Hash.try_convert({
    "sf" => 'San Francisco',
    "sea" => 'Seattle',
    "nyc" => 'New York',
    "dc" => 'Washington DC',
    "chi" => 'Chicago',
    "la" => 'Los Angeles',
    "aus" => 'Austin',
    "sby" => 'South Bay',
    "eby" => 'Easy Bay',
    "bos" => 'Boston',
    "mia" => 'Miami',
    "phi" => 'Philapelphia',
    "atl" => 'Atlanta',
    "dal" => 'Dallas',
    "den" => 'Denver',
    "hon" => 'Honolulu',
    "lv" => 'Las Vegas',
    "sd" => 'San Diego',
    "sj" => 'San Jose',
    "stl" => "St Louis",
    "hou" => 'Houston',
    "oc" => 'Orange County',
    "sac" => 'Sacremento',
    "phx" => 'Phoenix',
    "kc" => 'Kansas City'
})

def process_file(filename)

    ext = File.extname(filename)

    if ext == '.log'
        fd = File.open(filename)
    else
        print "ignoring #{filename} #{ext}\n"
        return
    end

    print "processing #{filename}"

    io = IO.new(fd.fileno,"r")

    MessagePack::Unpacker.new(io).each do | object |
        process_message(object)
    end
end

def process_message(message_object)

    type = message_object["type"]
    # pp message_object["type"]

    #Autoblitz metrics
    if type.match(/^postmates.evt.metrics.auto-blitz/) or
        type.match(/^postmates.evt.metrics.capacity/)
        name = type.split(".")[0..-2].join(".")
        market = type.split(".").last
        value = message_object["body"]["evt"]["value"]
        time = message_object["start"]
        event_object = {
            :value => value,
            :time => time,
            :market => $full_name_map[market]
        }
        $influxdb.write_point(name, event_object)
    end
end

Dir.foreach(DIR) do |log_file|
  next if log_file == '.' or log_file == '..'
  # pp log_file
  if log_file.match(/^postmates.evt.metrics.capacity/) or
        log_file.match(/^postmates.evt.metrics.auto-blitz/)

    process_file("#{DIR}#{log_file}")
  end
end
