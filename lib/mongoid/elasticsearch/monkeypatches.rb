# Quick fix for https://github.com/elasticsearch/elasticsearch-ruby/issues/43

require 'elasticsearch/api/actions/search'
module Elasticsearch
  module API
    module Actions
      def search(arguments={})
        arguments[:index] = '_all' if ! arguments[:index] && arguments[:type]

        valid_params = [
          :analyzer,
          :analyze_wildcard,
          :default_operator,
          :df,
          :explain,
          :fields,
          :from,
          :ignore_indices,
          :ignore_unavailable,
          :allow_no_indices,
          :expand_wildcards,
          :indices_boost,
          :lenient,
          :lowercase_expanded_terms,
          :preference,
          :q,
          :routing,
          :scroll,
          :search_type,
          :size,
          :sort,
          :source,
          :_source,
          :_source_include,
          :_source_exclude,
          :stats,
          :suggest_field,
          :suggest_mode,
          :suggest_size,
          :suggest_text,
          :timeout,
          :version ]

        method = 'GET'
        path   = Utils.__pathify( Utils.__listify(arguments[:index]), Utils.__listify(arguments[:type]), '_search' )

        params = Utils.__validate_and_extract_params arguments, valid_params
        body   = arguments[:body]

        params[:fields] = Utils.__listify(params[:fields]) if params[:fields]

        perform_request(method, path, params, body).body
      end
    end
  end
end
