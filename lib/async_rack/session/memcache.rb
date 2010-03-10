require "rack/memcache"

module AsyncRack
  module Session
    class Memcache < AsyncCallback(:Memcache, Rack::Session)
      def call(env)
        async_cb = env['async.callback']
        env['async.callback'] = Proc.new do |results|
          async_cb.call(commit_session(env, *result))
        end

        super(env)
      end
    end
  end
end
