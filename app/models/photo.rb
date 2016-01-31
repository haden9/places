class Photo
  attr_accessor :id, :location, :contents

  def initialize(params={})
    @id = params[:id].present? ? params[:id] : params[:_id].to_s
    @location = Point.new(params[:metadata][:location]) if params[:metadata].present?
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places_development]
  end
end
