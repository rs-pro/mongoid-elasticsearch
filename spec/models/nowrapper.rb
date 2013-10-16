class Nowrapper
  include Mongoid::Document

  field :name, type: String

  include Mongoid::Elasticsearch
  elasticsearch! wrapper: :none
end

