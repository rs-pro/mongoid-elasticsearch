module Mongoid
  module Elasticsearch
    class Es
      attr_reader :klass

      def initialize(klass)
        @klass = klass
      end

      def client
        # dup is needed because Elasticsearch::Client.new changes options hash inplace
        @client ||= ::Elasticsearch::Client.new klass.es_client_options.dup
      end

      def index
        @index ||= Index.new(self)
      end

      def search(query, options = {})
        if query.is_a?(String)
          query = {q: query}
        end

        page = options.delete(:page)
        per_page = options.delete(:per_page) || 50

        query[:size] = ( per_page.to_i ) if per_page
        query[:from] = ( page.to_i <= 1 ? 0 : (per_page.to_i * (page.to_i-1)) ) if page && per_page

        Response.new(client, query.merge(index: index.name), false, klass, klass.es_wrapper, options)
      end

      def options_for(obj)
        {index: index.name, type: index.type, id: obj.id.to_s}
      end

      def index_item(obj)
        client.index({body: obj.as_indexed_json}.merge(options_for(obj)))
      end

      def remove_item(obj)
        client.delete(options_for(obj))
      end

      def all(options = {})
        search({match_all: {}}, options)
      end

      def completion(text, field = "suggest")
        body = {
          text: clean_string(text),
          completion: {
            field: field
          }
        }
        results = client.suggest(index: index.name, body: body)
        results['q'][0]['options']
      end

      def clean_string(sq)
        sq.gsub(/\W+/, ' ').gsub(/ +/, '').strip
      end
    end
  end
end
