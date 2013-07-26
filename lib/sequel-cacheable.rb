# coding: utf-8
require 'sequel'
require 'sequel-cacheable/version'
require 'sequel-cacheable/driver'
require 'sequel-cacheable/class_methods'
require 'sequel-cacheable/instance_methods'
require 'sequel-cacheable/dataset_methods'

module Sequel::Plugins
  module Cacheable
    def self.configure(model, store, opts={})
      model.instance_eval do
        @cache_options = {
          :ttl => 3600,
          :cache_by_default => {
            :always => false,
            :if_limit => 1
          }
        }.merge(opts)

        @cache_driver = Driver.from_store(
          store,
          :serializer => @cache_options.delete(:serializer)
        )
      end
    end
  end
end
