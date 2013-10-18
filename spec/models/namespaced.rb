module Namespaced
  class Model
    include Mongoid::Document
    include Mongoid::Timestamps::Short
    include ActiveModel::ForbiddenAttributesProtection

    field :name

    include Mongoid::Elasticsearch
    elasticsearch! index_options: {
      'namespaced/model' => {
        mappings: {
          properties: {
            name: {
              type: 'string'
            }
          }
        }
      }
    }
  end
end
