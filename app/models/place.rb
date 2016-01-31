class Place

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(params={})
    @id = params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:location]) if params[:geometry].present?
    @address_components = []
    params[:address_components].each do |address_component|
      @address_components << AddressComponent.new(address_component)
    end
  end

  def self.find_by_short_name(short_name)
    collection.find({'address_components.short_name' => short_name})
  end

  def self.to_places(collection_view)
    places = []
    collection_view.each do |view|
      places << Place.new(view)
    end
    return places
  end

  def self.load_all(json_file)
    json_hash = JSON.parse(json_file.read)
    collection.insert_many(json_hash)
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places_development]
  end
end
