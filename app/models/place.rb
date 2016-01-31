class Place

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
