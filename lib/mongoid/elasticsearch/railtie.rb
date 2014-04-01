module Mongoid::Elasticsearch
  class Railtie < Rails::Railtie
    rake_tasks do
      require File.expand_path('../tasks', __FILE__)
    end
    
    config.after_initialize do
      Mongoid::Elasticsearch.create_all_indexes! if Mongoid::Elasticsearch.autocreate_indexes
    end
  end
end
