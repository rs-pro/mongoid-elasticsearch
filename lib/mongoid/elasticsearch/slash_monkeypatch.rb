# Monkeypatch for slashes to work

module Elasticsearch
  module API
    # Generic utility methods
    #
    module Utils
      alias_method :__pathify_without_slashes, :__pathify
      def __pathify(*segments)
        __pathify_without_slashes(*segments.map { |s| s.gsub('/', '%2F')}).gsub('%252F', '%2F')
      end
    end
  end
end
