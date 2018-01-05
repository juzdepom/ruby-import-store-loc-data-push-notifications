require 'json'
require 'uri'

require './bend'

total = 0

Dir['Locations – Json/*.json'].each do |file|
  # get the base filename without the path
  basename = File.basename(file)

  # split on period to separate the name from the .json extension
  filename, ext = basename.split('.')

  # split on hyphen to separate the store name from the id
  store_name, store_id = filename.split('-')

  store_id = store_id.to_i

  puts "#{store_name} – #{store_id}"

  # read the file and parse the JSON
  data = JSON::parse(File.read(file))

  puts "#{data.size} records"

  total += data.size

  data.each do |loc|
    # normalize keys to lowercase, combine lat/long into _geoloc
    doc = {
      store: store_name,
      storeId: store_id,
      location: loc['Name'],
      address1: loc['Address1'],
      address2: loc['Address2'],
      city: loc['City'],
      state: loc['State'],
      zipCode: loc['Postal'].to_s,
      _geoloc: [loc['Longitude'], loc['Latitude']],
    }

    # puts doc.to_json

    # Note: storeId is an integer (so no quotes), but converted to string with to_s
    # because we are adding (concatenating) strings here
    query = '{"storeId": ' + doc[:storeId].to_s + ', "zipCode": "' + doc[:zipCode] + '"}'

    # puts query
    # note: below isn't going to work unless I log into Bend and get the actual map key
    path = "/appdata/#{$APP_KEY}/store_locations?query=" + URI.escape(query).gsub('+','%2B').gsub('&','%26')

    # puts path

    res = $bend.get("https://api.bend.io" + path)
    existing = res.parse

    if existing.kind_of?(Array)
      if existing.empty?
        puts "Creating new #{doc[:store]} store at zipcode #{doc[:zipCode]}"
        # res = $bend.post("https://api.bend.io/appdata/#{$APP_KEY}/store_locations", json: doc)
        puts res.status
      else
        puts "#{doc[:store]} at #{doc[:zipCode]} already exists. Updating..."
        store = existing.first
        # res = $bend.put("https://api.bend.io/appdata/#{$APP_KEY}/store_locations/#{store['_id']}", json: doc)
      end
      # end -- if existing.empty?
    else
      puts "Unexpected response, some error must have occurred:\n#{res.body}"
    end
    # end -- if existing.kind_of?(Array)
    puts ''
  end
  # end -- data.each do |loc|
end
# end -- Dir['Locations – Json/*.json'].each do |file|
puts "Total files: #{total}"
