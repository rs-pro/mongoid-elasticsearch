class Article
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  field :name
  field :tags

  include Mongoid::Elasticsearch
  elasticsearch! index_name: 'mongoid_es_news', prefix_name: false, index_mappings: {
    name: {
      type: 'multi_field',
      fields: {
        name:     {type: 'string', analyzer: 'snowball'},
        raw:      {type: 'string', index: :not_analyzed},
        suggest:  {type: 'completion'} 
      }
    },
    tags: {type: 'string', include_in_all: false}
  }, wrapper: :load
end

