class Photo
  attr_accessor :id, :location, :contents

  def initialize
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places_development]
  end
end
