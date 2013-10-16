module Mongoid
  module Elasticsearch
    module Callbacks
      extend ActiveSupport::Concern

      included do
        after_save do
          es_update
        end

        after_destroy do
          es_delete
        end
      end
    end
  end
end

