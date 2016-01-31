class Photo
  attr_accessor :id, :location
  attr_writer :contents

  include ActiveModel::Model

  def initialize(params={})
    if params[:_id]
      @id = params[:_id].to_s if params[:_id].present?
    else
      @id = params[:id] if params[:id].present?
    end
    @location = Point.new(params[:metadata][:location]) if params[:metadata].present?
  end

  def destroy
    self.class.collection.find('_id' => BSON::ObjectId.from_string(@id)).
      delete_one
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
    unless persisted?
      if @contents
        description = {}
        description[:content_type] = {}
        description[:metadata] = {}
        description[:metadata][:location] = {}
        gps = EXIFR::JPEG.new(@contents).gps
        @location = Point.new({lng: gps.longitude, lat: gps.latitude})
        description[:content_type] = 'image/jpeg'
        description[:metadata][:location] = @location.to_hash
        @contents.rewind # need to remove the reference so that the contents method works
        grid_file = Mongo::Grid::File.new(@contents.read, description)
        id = self.class.collection.insert_one(grid_file)
        @id = id.to_s
      end
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client.database.fs
  end
end
