# coding: utf-8
module Sequel::Plugins
  module QueryCache
    class Driver
      def self.from_store(store, opts={})
        case store.class.name
        when 'Memcache'
          require 'sequel-query-cache/driver/memcache'
          MemcacheDriver.new(store, opts)
        when 'Dalli::Client'
          require 'sequel-query-cache/driver/dalli'
          DalliDriver.new(store, opts)
        else
          Driver.new(store, opts)
        end
      end

      attr_reader :store, :serializer

      def initialize(store, opts={})
        @store = store
        @serializer = opts[:serializer] || _default_serializer
      end

      def get(key)
        val = store.get(key)
        val ? serializer.deserialize(val) : nil
      end

      def set(key, val, opts={})
        store.set(key, serializer.serialize(val))
        expire(key, opts[:ttl]) unless opts[:ttl].nil?
        val
      end

      def del(key)
        store.del(key)
        nil
      end

      def expire(key, time)
        store.expire(key, time)
      end

      private

      def _default_serializer
        require 'sequel-query-cache/message_pack_serializer'
        MessagePackSerializer
      end
    end
  end
end
