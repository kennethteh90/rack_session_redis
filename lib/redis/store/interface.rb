class Redis
  class Store < self
    module Interface
      def get(key, _options = nil)
        super(key)
      end

      REDIS_SET_OPTIONS = %i(ex px nx xx keepttl).freeze
      private_constant :REDIS_SET_OPTIONS

      def set(key, value, options = nil)
        if options && REDIS_SET_OPTIONS.any? { |k| options.key?(k) }
          kwargs = REDIS_SET_OPTIONS.each_with_object({}) { |option_key, h| h[option_key] = options[option_key] if options.key?(option_key) }
          super(key, value, **kwargs)
        else
          super(key, value)
        end
      end

      def setnx(key, value, _options = nil)
        super(key, value)
      end

      def setex(key, expiry, value, _options = nil)
        super(key, expiry, value)
      end
    end
  end
end
