require "rack/commonlogger"

module AsyncRack
  class CommonLogger < AsyncCallback(:CommonLogger)
    def call(env)
      began_at = Time.now

      async_cb = env['async.callback']
      env['async.callback'] = Proc.new do |results|
        status, header, body = result

        header = Rack::Utils::HeaderHash.new header
        log(env, status, header, began_at)

        async_cb.call([status, header, body])
      end

      super(env)
    end
  end
end
