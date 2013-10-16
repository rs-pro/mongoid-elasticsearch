class Post
  include Mongoid::Document

  field :name, type: String
  field :content, type: String

  include Mongoid::Elasticsearch
  elasticsearch!
  def as_indexed_json
    {name: name, content: content}
  end
end

