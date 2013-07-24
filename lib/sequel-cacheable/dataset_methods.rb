# coding: utf-8
require 'digest/md5'

module Sequel::Plugins
  module Cacheable
    module DatasetMethods
      def cache_driver
        model.cache_driver
      end

      def cache_options
        model.cache_options
      end

      def is_cacheable?
        return @is_cacheable unless @is_cacheable.nil?
        _is_cacheable?
      end

      attr_writer :is_cacheable

      # TODO: Options passed here should override the defaults. However this
      # the dataset will need its own options apart from the model. (Eventually
      # this should work entirely without models anyway.
      def cached(opts={})
        c = clone
        c.is_cacheable = true
        c
      end

      def not_cached
        c = clone
        c.is_cacheable = false
        c
      end

      def default_cached
        if @is_cacheable.nil?
          self
        else
          c = clone
          c.is_cacheable = nil
          c
        end
      end

      def default_cache_key
        @default_cache_key ||= "Sequel:#{Digest::MD5.base64digest(sql)}"
      end

      def cache_key
        @cache_key || default_cache_key
      end

      def cache_key=(cache_key)
        @cache_key = cache_key ? cache_key.to_s : nil
      end

      def cache_get
        db.log_info("CACHE GET: #{cache_key}")
        cached_rows = cache_driver.get(cache_key)
        db.log_info("CACHE #{cached_rows ? 'HIT' : 'MISS'}: #{cache_key}")
        cached_rows
      end

      def cache_set(value, opts={})
        db.log_info("CACHE SET: #{cache_key}")
        cache_driver.set(cache_key, value, opts.merge(cache_options))
      end

      def cache_del
        db.log_info("CACHE DEL: #{cache_key}")
        cache_driver.del(cache_key)
      end

      def update(values={}, &block)
        result = super
        cache_del if is_cacheable?
        result
      end

      def delete(&block)
        result = super
        cache_del if is_cacheable?
        result
      end

      def fetch_rows(sql)
        if is_cacheable?
          if cached_rows = cache_get
            # Symbolize the row keys before yielding as they're often strings
            # when the data is deserialized.
            cached_rows.each{|r| yield r.reduce({}){|h,v| h[v[0].to_sym]=v[1]; h}}
          else
            cached_rows = []
            super(sql){|r| cached_rows << r}
            cache_set(cached_rows)
            cached_rows.each{|r| yield r}
          end
        else
          super
        end
      end

      def clone(opts=nil)
        c = super(opts)
        # Done because recalculating the MD5 hash every time cache_key is called
        # is ridiculous, so it's memoized. However, when the dataset is cloned,
        # it's usually for modification purposes in a chain, so that variable
        # needs to get cleared.
        c.instance_variable_set(:@default_cache_key, nil)
        c
      end

      private

      def _is_cacheable?
        if @opts[:limit] && cache_options[:cache_if_limit]
          return true if
            (cache_options[:cache_if_limit] == true) ||
            (cache_options[:cache_if_limit] >= @opts[:limit])
        end
        cache_options[:cache_by_default]
      end

    end
  end
end
