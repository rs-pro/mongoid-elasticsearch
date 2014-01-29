class Post
  include Mongoid::Document

  field :name, type: String
  field :content, type: String
  
  if defined?(Moped::BSON)
    field :my_object_id, type: Moped::BSON::ObjectId
  else
    field :my_object_id, type: BSON::ObjectId
  end
  

  include Mongoid::Elasticsearch
  elasticsearch!
  def as_indexed_json
    {name: name, content: content, my_object_id: my_object_id}
  end
end

