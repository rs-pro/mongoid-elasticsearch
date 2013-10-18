# Monkeypatch for slashes to work

module Elasticsearch
  module API
    # Generic utility methods
    #
    module Utils
      def __pathify(*segments)
        Array(segments).flatten.
          compact.
          reject { |s| s.to_s =~ /^\s*$/ }.
          map { |s| __escape(s) }.
          join('/').
          squeeze('/').gsub('%252F', '%2F')
      end
    end
  end
end
