# coding: utf-8
module Sequel::Plugins
  module Cacheable
    module InstanceMethods
      def after_save
        cache!
      end

      def cache_key
        this.cache_key
      end

      def cache!(opts={})
        this.cache_set([self], opts) if this.is_cacheable?
        self
      end

      def uncache!
        this.cache_del
        self
      end

      def to_msgpack(io=nil)
        values.to_msgpack(io)
      end
    end
  end
end
