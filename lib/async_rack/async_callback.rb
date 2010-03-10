module AsyncRack

  ##
  # @see AsyncRack::AsyncCallback
  def self.AsyncCallback(name, namespace = Rack)
    @wrapped ||= Hash.new { |h,k| h[k] = {} }
    @wrapped[namespace][name.to_sym] ||= namespace.const_get(name).tap do |klass|
      klass.extend AsyncCallback::InheritanceHook
      klass.alias_subclass name, namespace
    end
  end

  ##
  # Helps wrapping already existent middleware in a transparent manner.
  #
  # @example
  #   module Rack
  #     class FancyMiddleware
  #     end
  #   end
  #
  #   module AsyncRack
  #     class FancyMiddleware < AsyncCallback(:FancyMiddleware)
  #     end
  #   end
  #
  #   Rack::FancyMiddleware # => AsyncRack::FancyMiddleware
  #   AsyncRack::FancyMiddleware.ancestors # => [AsyncRack::AsyncCallback::Mixin, Rack::FancyMiddleware, ...]
  module AsyncCallback

    ##
    # Aliases a subclass on subclassing, but only once.
    # If that name already is in use, it will be replaced.
    #
    # @example
    #   class Foo
    #     def self.bar
    #       23
    #     end
    #   end
    #
    #   Foo.extend AsyncRack::AsyncCallback::InheritanceHook
    #   Foo.alias_subclass :Baz
    #
    #   class Bar < Foo
    #     def self.bar
    #       super + 19
    #     end
    #   end
    #
    #   Baz.bar # => 42
    module InheritanceHook

      ##
      # @param [Symbol] name Name it will be aliased to
      # @param [Class, Module] namespace The module the constant will be defined in
      def alias_subclass(name, namespace = Object)
        @alias_subclass = [name, namespace]
      end

      ##
      # @see InheritanceHook
      def inherited(klass)
        super
        if @alias_subclass
          name, namespace = @alias_subclass
          @alias_subclass = nil
          namespace.send :remove_const, name if namespace.const_defined? name
          namespace.const_set name, klass
          klass.send :include, AsyncRack::AsyncCallback::Mixin
        end
      end
    end

    module Mixin
      def call(env)
        async_cb = env['async.callback']
        env['async.callback'] = Proc.new do |result|
          async_cb.call(result)
        end

        super(env)
      end
    end

    ##
    # A simple wrapper is useful if the first thing a middleware does is something like
    # @app.call and then modifies the response.
    #
    # In that case you just have to include SimpleWrapper in your async wrapper class.
    module SimpleWrapper
      include AsyncRack::AsyncCallback::Mixin

      def initialize(app)
        super

        async_rack_app = app
        @app = Proc.new do |env|
          if env['async.results'].nil?
            async_rack_app.call(env)
          else
            env['async.results']
          end
        end
      end

      def call(env)
        async_cb = env['async.callback']
        env['async.callback'] = Proc.new do |results|
          env['async.results'] = results
          async_cb.call(super(env))
        end

        super(env)
      end
    end
  end
end