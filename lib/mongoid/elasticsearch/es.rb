module Mongoid
  module Elasticsearch
    class Es
      INDEX_STEP = 100
      attr_reader :klass, :version

      def initialize(klass)
        @klass = klass
        @version = Gem::Version.new(client.info['version']['number'])
      end

      def client
        # dup is needed because Elasticsearch::Client.new changes options hash inplace
        @client ||= ::Elasticsearch::Client.new klass.es_client_options.dup
      end

      def index
        @index ||= Index.new(self)
      end

      def index_all(step_size = INDEX_STEP)
        index.reset
        q = klass.asc(:id)
        steps = (q.count / step_size) + 1
        last_id = nil
        steps.times do |step|
          if last_id
            docs = q.gt(id: last_id).limit(step_size).to_a
          else
            docs = q.limit(step_size).to_a
          end
          last_id = docs.last.try(:id)
          docs = docs.map do |obj|
            if obj.es_index?
              { index: {data: obj.as_indexed_json}.merge(_id: obj.id.to_s) }
            else
              nil
            end
          end.reject { |obj| obj.nil? }
          next if docs.empty?
          client.bulk({body: docs}.merge(type_options))
          if block_given?
            yield steps, step
          end
        end       
      end

      def search(query, options = {})
        if query.is_a?(String)
          query = {q: Utils.clean(query)}
        end

        page = options[:page]
        per_page = options[:per_page].nil? ? options[:per] : options[:per_page]

        query[:size] = ( per_page.to_i ) if per_page
        query[:from] = ( page.to_i <= 1 ? 0 : (per_page.to_i * (page.to_i-1)) ) if page && per_page

        options[:wrapper] ||= klass.es_wrapper

        Response.new(client, query.merge(custom_type_options(options)), false, options[:scope] || klass, options)
      end

      def all(options = {})
        search({body: {query: {match_all: {}}}}, options)
      end

      def options_for(obj)
        {id: obj.id.to_s}.merge type_options
      end

      def custom_type_options(options)
        if !options[:include_type].nil? && options[:include_type] == false
          {index: index.name}
        else
          type_options
        end
      end

      def type_options
        {index: index.name, type: index.type}
      end

      def index_item(obj)
        client.index({body: obj.as_indexed_json}.merge(options_for(obj)))
      end

      def remove_item(obj)
        client.delete(options_for(obj).merge(ignore: 404))
      end

      def completion_supported?
        @version > Gem::Version.new('0.90.2')
      end

      def completion(text, field = "suggest")
        raise "Completion not supported in ES #{@version}" unless completion_supported?
        body = {
          q: {
            text: Utils.clean(text),
            completion: {
              field: field
            }
          }
        }
        results = client.suggest(index: index.name, body: body)
        results['q'][0]['options']
      end
    end
  end
end
