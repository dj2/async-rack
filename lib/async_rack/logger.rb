require "rack/logger"

module AsyncRack
  class Logger < AsyncCallback(:Logger)
    def call(env)
      logger = ::Logger.new(env['rack.errors'])
      logger.level = @level

      async_cb = env['async.callback']
      env['async.callback'] = Proc.new do |results|
        logger.close
        async_cb.call(results)
      end

      env['rack.logger'] = logger
      @app.call(env) # could throw :async
      logger.close
    rescue Exception => error # does not get triggered by throwing :async (ensure does)
      logger.close
      raise error
    end
  end
end
