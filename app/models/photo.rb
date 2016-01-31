class Photo
  attr_accessor :id, :location, :place
  attr_writer :contents

  include ActiveModel::Model

  def initialize(params={})
    if params[:_id]
      @id = params[:_id].to_s if params[:_id].present?
    else
      @id = params[:id] if params[:id].present?
    end
    if params[:metadata]
      @location = Point.new(params[:metadata][:location]) if params[:metadata][:location].present?
      @place = Place.find(params[:metadata][:place]) if params[:metadata][:place].present?
    end
  end

  def destroy
    self.class.collection.find('_id' => BSON::ObjectId.from_string(@id)).
      delete_one
  end

  def find_nearest_place_id(max_meters)
    document = Place.near(self.location, max_meters).limit(1).projection('_id' => 1).first
    document['_id']
  end

  def self.find_photos_for_place(id)
    bson_id = id.is_a?(String) ? BSON::ObjectId.from_string(id) : id
    collection.find('metadata.place' => bson_id)
  end

  def contents
    file = self.class.collection.find_one('_id' => BSON::ObjectId.from_string(@id))
    if file
      buffer = ''
      file.chunks.reduce([]) do |key, chunk|
        buffer << chunk.data.data
      end
      return buffer
    end
  end

  def persisted?
    !@id.nil?
  end

  def self.all(offset=0,limit=0)
    collection_view = collection.find.skip(offset).limit(limit)
    to_photos(collection_view)
  end

  def self.find(id)
    document = collection.find('_id' => BSON::ObjectId.from_string(id)).first
    return document.nil? ? nil : Photo.new(document)
  end

  def self.to_photos(collection_view)
    photos = []
    collection_view.each do |document|
      photos << Photo.new(document)
    end
    photos
  end

  def save
    description = {}
    description[:content_type] = {}
    description[:metadata] = {}
    description[:metadata][:location] = {}
    description[:metadata][:place] = {}
    if persisted?
      place_bson_id = @place.is_a?(BSON::ObjectId) ? @place : BSON::ObjectId.from_string(@place.id)
      self.class.collection.find('_id' => BSON::ObjectId.from_string(@id)).
        update_one('metadata' => {'location' => @location.to_hash,
          'place' => place_bson_id})
    else
      if @contents
        gps = EXIFR::JPEG.new(@contents).gps
        @location = Point.new({lng: gps.longitude, lat: gps.latitude})
        description[:content_type] = 'image/jpeg'
        description[:metadata][:location] = @location.to_hash
        description[:metadata][:place] = @place.nil? ? {} : BSON::ObjectId.from_string(@place.id)
        @contents.rewind # need to remove the reference so that the contents method works
        grid_file = Mongo::Grid::File.new(@contents.read, description)
        id = self.class.collection.insert_one(grid_file)
        @id = id.to_s
      end
    end
    @id
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client.database.fs
  end
end
