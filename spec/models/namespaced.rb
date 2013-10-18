module Namespaced
  class Model
    include Mongoid::Document
    include Mongoid::Timestamps::Short

    field :name

    include Mongoid::Elasticsearch
    elasticsearch!
  end
end
