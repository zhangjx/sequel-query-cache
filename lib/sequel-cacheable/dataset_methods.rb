# coding: utf-8
require 'digest/md5'

module Sequel::Plugins
  module Cacheable
    module DatasetMethods
      # Gets the cache driver from the model.
      #
      # TODO: It shouldn't actually do that. This plugin should work without
      # models being involved at all.
      def cache_driver
        model.cache_driver
      end

      # Gets the cache driver from the model.
      #
      # TODO: It shouldn't actually do that. This plugin should work without
      # models being involved at all. Datasets should have their own options,
      # specifically so they can be overridden by +cached+.
      def cache_options
        model.cache_options
      end

      # Determines whether or not a dataset should be cached. If +@is_cacheable+
      # is set to anything that is not +nil+, that value will be returned. If it
      # is +nil+ the a default value will be returned by </tt>_is_cacheable?</tt>.
      def is_cacheable?
        return @is_cacheable unless @is_cacheable.nil?
        _is_cacheable?
      end

      # Overrides the default value for </tt>_is_cacheable?</tt>. The value of
      # of +@is_cacheable+ is cloned when the dataset is cloned.
      attr_writer :is_cacheable

      # Clones the current dataset and forces it to be cached, returning
      # the new dataset. This is useful for chaining purposes:
      #
      #   dataset.where(column1: true).order(:column2).cached.all
      #
      # In the above example, the data would always be pulled from the cache or
      # cached if it wasn't already. The value of +@is_cacheable+ is cloned
      # when a dataset is cloned, so the following example would also have the
      # same result:
      #
      #   dataset.cached.where(column1: true).order(:column2).all
      #
      # TODO: Options passed here should override the defaults. However this
      # the dataset will need its own options apart from the model. (Eventually
      # this should work entirely without models anyway.
      def cached(opts={})
        c = clone
        c.is_cacheable = true
        c
      end

      # Clones the current dataset and forces it to not be cached, returning
      # the new dataset. See +cached+ for further details and examples.
      def not_cached
        c = clone
        c.is_cacheable = false
        c
      end

      # Clones the current dataset and returns the caching state to whatever
      # would be default for that dataset. See +cached+ for further details
      # and examples.
      def default_cached
        if @is_cacheable.nil?
          self
        else
          c = clone
          c.is_cacheable = nil
          c
        end
      end

      # Creates a default cache key, which is an MD5 base64 digest of the
      # the literal select SQL with +Sequel:+ added as a prefix. This value is
      # memoized because assembling the SQL string and hashing it every time
      # this method gets called is obnoxious.
      def default_cache_key
        @default_cache_key ||= "Sequel:#{Digest::MD5.base64digest(sql)}"
      end

      # Returns the default cache key if a manual cache key has not been set.
      # The cache key is used by the storage engines to retrieve cached data.
      # The default will suffice in almost all instances.
      def cache_key
        @cache_key || default_cache_key
      end

      # Sets a manual cache key for a dataset that overrides the default MD5
      # hash. This key has no +Sequel:+ prefix, so if that's important, remember
      # to add it manually.
      #
      # *Note:* Setting the cache key manually is *NOT* inherited by cloned
      # datasets since keys are presumed to be for the current dataset and any
      # changes, such as where clauses or limits, should result in a new key. In
      # general, you shouldn't change the cache key unless you have a really
      # good reason for doing so.
      def cache_key=(cache_key)
        @cache_key = cache_key ? cache_key.to_s : nil
      end

      # Gets the cache value using the current dataset's key and logs the
      # action. The underlying driver should return +nil+ in the event that
      # there is no cached data. Also logs whether there was a hit or miss on
      # the cache.
      def cache_get
        db.log_info("CACHE GET: #{cache_key}")
        cached_rows = cache_driver.get(cache_key)
        db.log_info("CACHE #{cached_rows ? 'HIT' : 'MISS'}: #{cache_key}")
        cached_rows
      end

      # Sets the cache value using the current dataset's key and logs the
      # action. In general, this method should not be called directly. It's
      # exposed because model instances need access to it.
      #
      # An +opts+ hash can be passed to override any default options being sent
      # to the driver. The most common use for this would be to modify the +ttl+
      # for a cache. However, this should probably be done using the +cached+
      # method rather than doing anything directly via this method.
      def cache_set(value, opts={})
        db.log_info("CACHE SET: #{cache_key}")
        cache_driver.set(cache_key, value, opts.merge(cache_options))
      end

      # Deletes the cache value using the current dataset's key and logs the
      # action.
      def cache_del
        db.log_info("CACHE DEL: #{cache_key}")
        cache_driver.del(cache_key)
      end

      # Overrides the dataset's existing +update+ method. Deletes an existing
      # cache after a successful update.
      def update(values={}, &block)
        result = super
        cache_del if is_cacheable?
        result
      end

      # Overrides the dataset's existing +delete+ method. Deletes an existing
      # cache after a successful delete.
      def delete(&block)
        result = super
        cache_del if is_cacheable?
        result
      end

      # Overrides the dataset's existing +fetch_rows+ method. If the dataset is
      # cacheable it will do one of two things:
      #
      # 1. If a cache exists it will yield the cached rows rather query the
      # database.
      # 2. If a cache does not exist it will query the database, store the
      # results in an array, cache those and then yield the results like the
      # original method would have.
      #
      # *Note:* If you're using PostgreSQL, or another database where +each+
      # iterates with the cursor rather over the returned dataset, you'll lose
      # that functionality when caching is enabled for a query since the entire
      # result is iterated first before it is yielded. If that behavior is
      # important, remember to disable caching for that particular query.
      def fetch_rows(sql)
        if is_cacheable?
          if cached_rows = cache_get
            # Symbolize the row keys before yielding as they're often strings
            # when the data is deserialized. Sequel doesn't play nice with
            # string keys.
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

      # Overrides the dataset's existing +clone+ method. Clones the existing
      # dataset but clears any manually set cache key and the memoized default
      # cache key to ensure it's regenerated by the new dataset.
      def clone(opts=nil)
        c = super(opts)
        c.cache_key = nil
        c.instance_variable_set(:@default_cache_key, nil)
        c
      end

      private

      # Determines whether or not to cache a dataset based on the configuration
      # settings of the plugin.
      #
      # TODO: Specify a place to find those settings. However, where those are
      # applied is currently in flux.
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
