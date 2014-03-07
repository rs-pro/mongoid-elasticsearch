module Mongoid
  module Elasticsearch
    module Callbacks
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        after_save :update_es_index
        after_destroy :update_es_index
      end

      module InstanceMethods
        def update_es_index
          es_update
        end
      end

      module ClassMethods
        def without_es_update!( &block )
          skip_callback( :save, :after, :update_es_index )
          skip_callback( :destroy, :after, :update_es_index )
          
          result = yield

          set_callback( :save, :after, :update_es_index )
          set_callback( :destroy, :after, :update_es_index )
          
          result
        end        
      end
    end
  end
end

