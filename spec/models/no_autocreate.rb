class NoAutocreate
  include Mongoid::Document

  field :name, type: String

  include Mongoid::Elasticsearch
  elasticsearch! skip_create: true
end

