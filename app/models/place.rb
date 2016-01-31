class Place

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(params={})
    @id = params[:id].present? ? params[:id] : params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:location]) if params[:geometry].present?
    @address_components = []
    params[:address_components].each do |address_component|
      @address_components << AddressComponent.new(address_component)
    end
  end

  def self.get_address_components(sort={'_id'=>1},offset=0,limit=nil)
    if limit
      collection.find.aggregate([{'$sort' => sort}, {'$skip' => offset}, {'$limit' => limit},
        {'$project' => {'_id' => 1, 'address_components' => 1, 'formatted_address' => 1,
                           'geometry.geolocation' => 1}}
      ])
    else
      collection.find.aggregate([{'$sort' => sort}, {'$skip' => offset},
        {'$unwind' => '$address_components'},
        {'$project' => {'_id' => 1, 'address_components' => 1, 'formatted_address' => 1,
                           'geometry.geolocation' => 1}}
      ])
    end
  end

  def destroy
    self.class.collection.delete_one(:_id => BSON::ObjectId.from_string(@id))
  end

  def self.all(offset=0,limit=nil)
    collection_view = []
    if limit
      collection_view = collection.find.skip(offset).limit(limit)
    else
      collection_view = collection.find.skip(offset)
    end
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
