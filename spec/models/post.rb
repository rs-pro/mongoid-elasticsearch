class Post
  include Mongoid::Document

  field :name, type: String
  field :content, type: String

  field :my_object_id, type: BSON::ObjectId

  include Mongoid::Elasticsearch
  elasticsearch!
  def as_indexed_json
    {name: name, content: content, my_object_id: my_object_id}
  end
end

