class Photo
  attr_accessor :id, :location
  attr_writer :contents

  include ActiveModel::Model

  def initialize(params={})
    if params[:_id]
      @id = params[:_id].to_s
    else
      @id = params[:id]
    end
    @location = Point.new(params[:metadata][:location]) if params[:metadata].present?
  end

  def persisted?
    !@id.nil?
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
        grid_file = Mongo::Grid::File.new(@contents.read, description)
        id = self.class.mongo_client.database.fs.insert_one(grid_file)
        @id = id.to_s
      end
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places_development]
  end
end
