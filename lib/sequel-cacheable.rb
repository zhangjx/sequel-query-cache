# coding: utf-8
require 'sequel'
require 'sequel-cacheable/version'
require 'sequel-cacheable/driver'
require 'sequel-cacheable/class_methods'
require 'sequel-cacheable/instance_methods'
require 'sequel-cacheable/dataset_methods'

module Sequel::Plugins
  module Cacheable
    CACHE_BY_DEFAULT_PROC = lambda do |ds, opts|
      if ds.opts[:limit] && opts[:if_limit]
        return true if
          (opts[:if_limit] == true) ||
          (opts[:if_limit] >= ds.opts[:limit])
      end

      false
    end

    def self.configure(model, store, opts={})
      model.instance_eval do
        @cache_options = {
          :ttl => 3600,
          :cache_by_default => {
            :proc => CACHE_BY_DEFAULT_PROC,
            :always => true,
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
