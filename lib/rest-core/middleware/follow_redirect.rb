
require 'rest-core/middleware'

class RestCore::FollowRedirect
  def self.members; [:max_redirects]; end
  include RestCore::Middleware

  def call env, &k
    e = env.merge('follow_redirect.max_redirects' =>
                    env['follow_redirect.max_redirects'] ||
                    max_redirects(env))

    if e[DRY]
      app.call(e, &k)
    else
      app.call(e){ |res| process(res, k) }
    end
  end

  def process res, k
    return k.call(res) if res['follow_redirect.max_redirects'] <= 0
    return k.call(res) if ![301,302,303,307].include?(res[RESPONSE_STATUS])
    return k.call(res) if  [301,302    ,307].include?(res[RESPONSE_STATUS]) &&
                          ![:get, :head    ].include?(res[REQUEST_METHOD])

    location = [res[RESPONSE_HEADERS]['LOCATION']].flatten.first
    meth     = if res[RESPONSE_STATUS] == 303
                 :get
               else
                 res[REQUEST_METHOD]
               end

    call(res.merge(REQUEST_METHOD => meth    ,
                   REQUEST_PATH   => location,
                   REQUEST_QUERY  => {}      ,
                   'follow_redirect.max_redirects' =>
                     res['follow_redirect.max_redirects'] - 1), &k)
  end
end
