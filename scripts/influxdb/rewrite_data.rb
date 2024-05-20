require 'influxdb'
require 'pp'

database = 'production'
username = 'root'
password = 'root'
host ="influxdb.postmates.com"
time_precision = 'ms'

influxdb = InfluxDB::Client.new database, :host => host,
                :username => username, :password => password, :time_precision => time_precision

#  Be careful this crashed influxdb last time you used it.
#  I am still not 100% sure what caused the crash

def convert_point point
    if point["courier_price_quote"].to_f > 100.0
        return nil
    end

    point["courier_price_quote"] = Integer(point["courier_price_quote"].to_f * 100)
    return point
end

influxdb.query 'select * from postmates.evt.metrics.dispatch.pickup_distance' do |name, points|
    pp name
    #pp points

    pp "#{points.length} records"
    points.each do | point |
        next if point["courier_price_quote"].to_f > 100.0
        pp point
    end
    # points = points.map{ |point| convert_point point }.reject{ |point| point.nil? }
    # influxdb.write_point(name, points)
    # print "#{points.length} records updated"
end


