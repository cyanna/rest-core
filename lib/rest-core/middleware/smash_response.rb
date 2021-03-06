
require 'rest-core/util/smash'

module RestCore
  class SmashResponse
    def self.members; [:smash_response]; end
    include Middleware

    def call env, &k
      return app.call(env, &k) if env[DRY]
      return app.call(env, &k) unless smash_response(env)

      app.call(env){ |res|
        if res[RESPONSE_BODY].kind_of?(Hash)
          yield(res.merge(RESPONSE_BODY => Smash.new(res[RESPONSE_BODY])))
        else
          yield(res)
        end
      }
    end
  end
end
