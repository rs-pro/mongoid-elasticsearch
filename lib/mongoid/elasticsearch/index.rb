module Mongoid
  module Elasticsearch
    class Index
      def initialize(es)
        @es = es
      end

      def klass
        @es.klass
      end

      def name
        klass.es_index_name
      end

      def type
        klass.es_index_type
      end

      def options
        klass.es_index_options
      end

      def indices
        @es.client.indices
      end

      def exists?
        indices.exists index: name
      end

      def create
        unless options == {} || exists?
          force_create
        end
      end

      def force_create
        indices.create index: name, body: options
      end

      def delete
        if exists?
          force_delete
        end
      end

      def force_delete
        indices.delete index: name
      end

      def refresh
        indices.refresh index: name
      end

      def reset
        delete
        create
      end
    end
  end
end
