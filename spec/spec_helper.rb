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

if ENV['CI_ADAPTER'] == 'httpclient'
  require 'httpclient'
  DEFAULT_OPT = {adapter: :httpclient}
else
  DEFAULT_OPT = {}
end
Mongoid::Elasticsearch.client_options = DEFAULT_OPT.dup
Mongo::Logger.logger.level = ::Logger::FATAL

# Mongoid::Elasticsearch.client_options = {log: true}

# Mongoid::Elasticsearch.client_options = {urls: ['http://127.0.0.1:9205']}
Mongoid::Elasticsearch.prefix = "mongoid_es_test_"
I18n.enforce_available_locales = true

Dir["#{MODELS}/*.rb"].each { |f| require f }

Mongoid.configure do |config|
  config.connect_to "mongoid_elasticsearch_test"
  #config.logger = Logger.new($stdout, :info)
end
#Moped.logger = Logger.new($stdout, Logger::DEBUG)

DatabaseCleaner.orm = "mongoid"

RSpec.configure do |config|
  config.before(:all) do
    #DatabaseCleaner.strategy = :truncation
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
