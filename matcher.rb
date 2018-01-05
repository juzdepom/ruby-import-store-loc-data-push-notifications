require 'redis'
require 'json'

require './bend'

# need to have redis running in order for this to work
# redis-server into termial
$redis = Redis.new

tokens = [
  "334a3159694e408e3471feb09592f33230f46783935dd167d84271d9b659d19e", # Julia
  "287e4d70085a0327101457e82bb180286bc41b5c4271ae900037d74a805c676c", # Kostas
]

def haversine_distance(geo_a, geo_b, miles=false)
  # Get latitude and longitude
  lat1, lon1 = geo_a
  lat2, lon2 = geo_b

  # Calculate radial arcs for latitude and longitude
  dLat = (lat2 - lat1) * Math::PI / 180
  dLon = (lon2 - lon1) * Math::PI / 180


  a = Math.sin(dLat / 2) *
      Math.sin(dLat / 2) +
      Math.cos(lat1 * Math::PI / 180) *
      Math.cos(lat2 * Math::PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2)

  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))

  d = 6371 * c * (miles ? 1 / 1.6 : 1)
end


# get an array of stores that have active campaigns
def stores_with_active_campaigns
  # hard-coded for now
  return [
    {id: 4168, name: "Ashley Stewart"},
    {id: 789, name: "Best Buy"}
  ]
end


def locations_for_store_ids(store_ids)
  # fetch all relevant locations from bend
  query = '{"storeId": {"$in": [' + store_ids.join(',') + ']}}'

  puts query

  path = "/appdata/#{$APP_KEY}/store_locations?query=" + URI.escape(query).gsub('+','%2B').gsub('&','%26')

  puts path

  res = $bend.get("https://api.bend.io" + path)

  res.parse

end

# time how long
start = Time.now

# in this case would be 4168 and 789
active_store_ids = stores_with_active_campaigns.collect { |s| s[:id] }
active_store_locations = locations_for_store_ids(active_store_ids)

#puts JSON::pretty_generate(active_locations)

i = 0
matches = 0

#the actual file that we were working on had 600k inputs
File.foreach("location-updates.log") do |line|
  i += 1
  data = JSON::parse(line)

  lat = data['lat']
  long = data['long']
  token = data['apns_token']
  next if token.nil?

  #puts "#{lat}, #{long} – #{token}"

  active_store_locations.each do |loc|

    slong = loc['_geoloc'][0]
    slat = loc['_geoloc'][1]

    store = loc['store']

    dist = haversine_distance([lat, long], [slat, slong], true)

    #puts dist

    if dist < 0.25
      matches += 1
      puts "WE HAVE A MATCH AT #{i} – #{matches} total"

      data = {
        tokens: tokens,
        badge: 0,
        alert: "Near " + store + "? Check out this coupon",
        sound: "RecommendedOffer_1.aif",
        data: {
          screen: "coupon",
          target: "2686723",
        }
      }

      puts data.to_json
      # refer to pusher.rb
      $redis.rpush("snipsnap:push" , data.to_json)
      break

    end

  end
  break if matches > 3
end

duration = Time.now.to_f - start.to_f

puts "Duration: #{duration}"
