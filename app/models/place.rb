class Place

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(params={})
    @id = params[:id].present? ? params[:id] : params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:geolocation]) if params[:geometry].present?
    @address_components = []
    if params[:address_components].present?
      params[:address_components].each do |address_component|
        @address_components << AddressComponent.new(address_component)
      end
    end
  end

  def self.get_address_components(sort={'_id'=>1},offset=0,limit=nil)
    if limit
      collection.find.aggregate([{'$unwind' => '$address_components'},
        {'$project' => {'_id' => 1, 'address_components' => 1, 'formatted_address' => 1,
                           'geometry.geolocation' => 1}},
        {'$sort' => sort}, {'$skip' => offset}, {'$limit' => limit},
      ])
    else
      collection.find.aggregate([{'$unwind' => '$address_components'},
        {'$project' => {'_id' => 1, 'address_components' => 1, 'formatted_address' => 1,
                           'geometry.geolocation' => 1}},
        {'$sort' => sort}, {'$skip' => offset}
      ])
    end
  end

  def self.get_country_names
    collection.find.aggregate([{'$unwind' => '$address_components'},
      {'$match' => {'address_components.types' => 'country'}},
      {'$project' => {'_id' => 1, 'address_components.long_name' => 1,
        'address_components.types' => 1}},
      {'$group' => {'_id' => '$address_components.long_name'}}
    ]).to_a.to_a.map {|document| document[:_id]}
  end

  def self.find_ids_by_country_code(country_code)
    collection.find.aggregate([{'$match' => {'address_components.short_name' => country_code,
        'address_components.types' => 'country'}},
      {'$project' => {'_id' => 1}}
    ]).map {|document| document[:_id].to_s}
  end

  def destroy
    self.class.collection.delete_one(:_id => BSON::ObjectId.from_string(@id))
  end

  def self.all(offset=0,limit=0)
    collection_view = collection.find.skip(offset).limit(limit)
    to_places(collection_view)
  end

  def self.find(id)
    document = collection.find(:_id => BSON::ObjectId.from_string(id)).first
    return document.nil? ? nil : Place.new(document)
  end

  def self.find_by_short_name(short_name)
    collection.find({'address_components.short_name' => short_name})
  end

  def self.to_places(collection_view)
    places = []
    collection_view.each do |document|
      places << Place.new(document)
    end
    places
  end

  def self.create_indexes
    collection.indexes.create_one({'geometry.geolocation' => '2dsphere'})
  end

  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  def self.near(point, max_meters=0)
    collection.find({'geometry.geolocation' => {'$near' => { '$geometry' => point.to_hash,
      '$maxDistance' => max_meters}}}
    )
  end

  def near(max_meters=0)
    collection_view = self.class.near(@location, max_meters).to_a
    self.class.to_places(collection_view)
  end

  def self.load_all(json_file)
    json_hash = JSON.parse(json_file.read)
    collection.insert_many(json_hash)
  end

  def self.reset
    file_path = './db/places.json'
    if File.exists?(file_path)
      all.each {|place| place.destroy}
      load_all(File.open(file_path))
    else
      puts 'places.json file not found'
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places_development]
  end
end
