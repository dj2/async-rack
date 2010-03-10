require "rack/runtime"

module AsyncRack
  class Runtime < AsyncCallback(:Runtime)
    def call(env)
      start_time = Time.now

      async_cb = env['async.callback']
      env['async.callback'] = Proc.new do |results|
        status, headers, body =result
        request_time = Time.now - start_time
        headers[@header_name] = "%0.6f" % request_time if !headers.has_key?(@header_name)

        async_cb.call([status, headers, body])
      end

      super
    end
  end
end