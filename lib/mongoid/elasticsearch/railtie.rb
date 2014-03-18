module Mongoid::Elasticsearch
  class Railtie < Rails::Railtie
    rake_tasks do
      require File.expand_path('../tasks', __FILE__)
    end
    
    initializer 'elasticsearch.load_app' do
      Mongoid::Elasticsearch.create_all_indexes!
    end
  end
end
