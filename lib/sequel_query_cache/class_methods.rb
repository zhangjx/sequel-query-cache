# encoding: utf-8

module Sequel::Plugins
  module QueryCache
    module ClassMethods

      attr_reader :cache_driver, :cache_options

      def inherited(subclass)
        super
        subclass.inherit_options(@cache_options, @cache_driver)
      end

      def inherit_options(cache_options, cache_driver)
        @cache_options ||= {}
        @cache_options.merge!(cache_options)
        @cache_driver = cache_driver
      end

      def cached(opts={})
        dataset.cached(opts)
      end

      def not_cached
        dataset.not_cached
      end

      def default_cached
        dataset.default_cached
      end
    end
  end
end
