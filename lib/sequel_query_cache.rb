# encoding: utf-8

require 'sequel'

require_relative 'sequel_query_cache/version'
require_relative 'sequel_query_cache/driver'
require_relative 'sequel_query_cache/class_methods'
require_relative 'sequel_query_cache/instance_methods'
require_relative 'sequel_query_cache/dataset_methods'

module Sequel::Plugins
  module QueryCache
    def self.configure(model, store, opts={})
      model.instance_eval do
        @cache_options = {
          :ttl => 3600,
          :cache_by_default => {
            :always => false,
            :if_limit => 1
          }
          #:serializer =>
        }.merge(opts)

        @cache_driver = Driver.from_store(
          store,
          :serializer => @cache_options.delete(:serializer)
        )
      end
    end
  end
end
