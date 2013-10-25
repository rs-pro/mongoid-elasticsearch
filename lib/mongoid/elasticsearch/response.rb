# partially based on https://github.com/karmi/retire/blob/master/lib/tire/results/collection.rb

require 'mongoid/elasticsearch/pagination'

module Mongoid
  module Elasticsearch
    class Response
      include Enumerable
      include Pagination

      attr_reader :time, :total, :options, :facets, :max
      attr_reader :response

      def initialize(client, query, multi, model, options)
        @client  = client
        @query   = query
        @multi   = multi
        @model   = model
        @wrapper = options[:wrapper]
        @options = options
      end

      def perform!
        response = @client.search(@query)
        @options = options
        @time = response['took'].to_i
        @total = response['hits']['total'].to_i rescue nil
        @facets = response['facets']
        @max_score = response['hits']['max_score'].to_f rescue nil
        response
      end

      def total
        if @total.nil?
          perform!
          @total
        else
          @total
        end
      end

      def raw_response
        @raw_response ||= perform!
      end

      def hits
        @hits ||= raw_response['hits']['hits']
      end

      def results
        return [] if failure?
        @results ||= begin
          case @wrapper
          when :load
            if @multi
              multi_with_load
            else
              @model.find(hits.map { |h| h['_id'] })
            end
          when :mash
            hits.map do |h|
              s = h.delete('_source')
              m = Hashie::Mash.new(h.merge(s))
              m.id = BSON::ObjectId.from_string(h['_id'])
              m._id = m.id
              m
            end
          when :model
            multi_without_load
          else
            hits
          end

        end
      end

      def error
        raw_response['error']
      end

      def success?
        error.to_s.empty?
      end

      def failure?
        !success?
      end

      def each(&block)
        results.each(&block)
      end

      def to_ary
        results
      end

      def inspect
        "#<Mongoid::Elasticsearch::Response @size:#{size} @results:#{results.inspect} @error=#{success? ? "none" : error} @raw_response=#{raw_response}>"
      end

      def count
        # returns approximate counts, for now just using search_type: 'count',
        # which is exact
        # @total ||= @client.count(@query)['count']

        @total ||= @client.search(@query.merge(search_type: 'count'))['hits']['total']
      end

      def size
        results.size
      end
      alias_method :length, :size

      private

      def find_klass(type)
        raise NoMethodError, "You have tried to eager load the model instances, " +
                             "but Mongoid::Elasticsearch cannot find the model class because " +
                             "document has no _type property." unless type

        begin
          klass = type.camelize.singularize.constantize
        rescue NameError => e
          raise NameError, "You have tried to eager load the model instances, but " +
                           "Mongoid::Elasticsearch cannot find the model class '#{type.camelize}' " +
                           "based on _type '#{type}'.", e.backtrace
        end
      end

      def multi_with_load
        return [] if hits.empty?

        records = {}
        hits.group_by { |item| item['_type'] }.each do |type, items|
          klass = find_klass(type)
          records[type] = klass.find(items.map { |h| h['_id'] })
        end

        # Reorder records to preserve the order from search results
        hits.map do |item|
          records[item['_type']].detect do |record|
            record.id.to_s == item['_id'].to_s
          end
        end
      end

      def multi_without_load
        hits.map do |h|
          klass = find_klass(h['_type'])
          source = h.delete('_source')
          begin
            m = klass.new(h.merge(source))
          rescue Mongoid::Errors::UnknownAttribute
            klass.class_eval <<-RUBY, __FILE__, __LINE__+1
              attr_accessor :_type, :_score, :_source
            RUBY
            m = klass.new(h.merge(source))
          end
          m.new_record = false
          m
        end
      end
    end
  end
end
