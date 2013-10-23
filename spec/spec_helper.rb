require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

MODELS = File.join(File.dirname(__FILE__), "models")

require "rubygems"
require "rspec"
require "mongoid"
require "hashie"
require "mongoid_slug"
require "database_cleaner"

require "mongoid-elasticsearch"

Mongoid::Elasticsearch.prefix = "mongoid_es_test_"

Dir["#{MODELS}/*.rb"].each { |f| require f }

Mongoid.configure do |config|
  config.connect_to "mongoid_elasticsearch_test"
  config.logger = Logger.new($stdout, :info)
end
Moped.logger = Logger.new($stdout, Logger::DEBUG)

DatabaseCleaner.orm = "mongoid"

RSpec.configure do |config|
  config.before(:all) do
    DatabaseCleaner.strategy = :truncation
    Article.es.index.reset
    Post.es.index.reset
    Nowrapper.es.index.reset
    Namespaced::Model.es.index.reset
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
    Article.es.index.reset
    Post.es.index.reset
    Nowrapper.es.index.reset
    Namespaced::Model.es.index.reset
  end

  config.after(:all) do
    DatabaseCleaner.clean
    Article.es.index.delete
    Post.es.index.delete
    Nowrapper.es.index.delete
    Namespaced::Model.es.index.delete
  end
end
