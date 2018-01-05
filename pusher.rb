require 'houston'
require 'redis'
require 'json'

# Production Redis
#$redis = Redis.new(host: 'db1.invalid.snipsnap.it', timeout: 5)

# Development / Local Redis
$redis = Redis.new

$log = File.open('push.log', 'a')

APN = Houston::Client.production
# note: I altered snipsnap-production so that it would not work
# just added it as a reference to what it would look like
APN.certificate = File.read("snipsnap-production.pem")


while true

  key, data = $redis.brpop('snipsnap:push', 0)

  $log.puts("#{Time.now.to_s}\t#{data}")

  puts data

  next if data.nil?

  data = JSON::parse(data)

  tokens = data['tokens']
  badge = data['badge'] || 0
  alert = data['alert']
  sound = data['sound'] || 'RecommendedOffer_1.aif'
  params = data['data']

  next if tokens.nil? or tokens.empty?

  tokens.each do |token|
    notification = Houston::Notification.new(device: token)
    notification.alert = alert
    notification.sound = sound
    notification.custom_data = params
    begin
      puts APN.push(notification).inspect
    rescue => e
      puts "ERROR: #{e.inspect}"
    end
  end

end
