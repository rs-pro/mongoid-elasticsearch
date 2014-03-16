require 'mongoid/elasticsearch/version'

require 'elasticsearch'
require 'active_support/concern'

require 'mongoid/elasticsearch/utils'
require 'mongoid/elasticsearch/es'
require 'mongoid/elasticsearch/callbacks'
require 'mongoid/elasticsearch/index'
require 'mongoid/elasticsearch/indexing'
require 'mongoid/elasticsearch/response'

require 'mongoid/elasticsearch/monkeypatches'

module Mongoid
  module Elasticsearch
    mattr_accessor :prefix
    self.prefix = ''

    mattr_accessor :client_options
    self.client_options = {}

    mattr_accessor :registered_indexes
    self.registered_indexes = []

    extend ActiveSupport::Concern
    included do
      def self.es
        @__es__ ||= Mongoid::Elasticsearch::Es.new(self)
      end

      # Add elasticsearch to the model
      # @option index_name [String] name of the index for this model
      # @option index_options [Hash] Index options to be passed to Elasticsearch
      # when creating an index
      # @option client_options [Hash] Options for Elasticsearch::Client.new
      # @option wrapper [Symbol] Select what wrapper to use for results
      # possible options:
      # :model - creates a new model instance, set its attributes, and marks it as persisted
      # :mash - Hashie::Mash for object-like access  (perfect for simple models, needs gem 'hashie')
      # :none - raw hash
      # :load - load models from Mongo by IDs
      def self.elasticsearch!(options = {})
        options = {
          prefix_name: true,
          index_name: nil,
          client_options: {},
          index_options: {},
          index_mappings: nil,
          wrapper: :model,
          callbacks: true
        }.merge(options)
        
        if options[:wrapper] == :model
          attr_accessor :_type, :_score, :_source
        end

        cattr_accessor :es_client_options, :es_index_name, :es_index_options, :es_wrapper

        self.es_client_options = Mongoid::Elasticsearch.client_options.dup.merge(options[:client_options])
        self.es_index_name     = (options[:prefix_name] ? Mongoid::Elasticsearch.prefix : '') + (options[:index_name] || model_name.plural)
        self.es_index_options  = options[:index_options]
        self.es_wrapper        = options[:wrapper]

        Mongoid::Elasticsearch.registered_indexes.push self.es_index_name

        unless options[:index_mappings].nil?
          self.es_index_options = self.es_index_options.deep_merge({
            :mappings => {
              es.index.type.to_sym => {
                :properties => options[:index_mappings]
              }
            }
          })
        end

        include Indexing
        include Callbacks if options[:callbacks]

        es.index.create
      end
    end

    # search multiple models
    def self.search(query, options = {})
      if query.is_a?(String)
        query = {q: Utils.clean(query)}
      end
      # use `_all` or empty string to perform the operation on all indices
      # regardless whether they are managed by Mongoid::Elasticsearch or not
      unless query.key?(:index)
        query.merge!(index: Mongoid::Elasticsearch.registered_indexes.join(','), ignore_indices: 'missing', ignore_unavailable: true)
      end

      page = options[:page]
      per_page = options[:per_page]

      query[:size] = ( per_page.to_i ) if per_page
      query[:from] = ( page.to_i <= 1 ? 0 : (per_page.to_i * (page.to_i-1)) ) if page && per_page

      options[:wrapper] ||= :model

      client = ::Elasticsearch::Client.new Mongoid::Elasticsearch.client_options
      Response.new(client, query, true, nil, options)
    end
  end
end
