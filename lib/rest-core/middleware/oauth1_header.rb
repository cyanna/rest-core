
require 'rest-core/middleware'
require 'rest-core/util/hmac'

require 'uri'
require 'openssl'

# http://tools.ietf.org/html/rfc5849
class RestCore::Oauth1Header
  def self.members
    [:request_token_path, :access_token_path, :authorize_path,
     :consumer_key, :consumer_secret,
     :oauth_callback, :oauth_verifier,
     :oauth_token, :oauth_token_secret, :data]
  end
  include RestCore::Middleware
  def call env, &k
    start_time = Time.now
    headers = {'Authorization' => oauth_header(env)}.
                merge(env[REQUEST_HEADERS])

    event = Event::WithHeader.new(Time.now - start_time,
              "Authorization: #{headers['Authorization']}")

    app.call(log(env.merge(REQUEST_HEADERS => headers), event), &k)
  end

  def oauth_header env
    oauth = attach_signature(env,
      'oauth_consumer_key'     => consumer_key(env),
      'oauth_signature_method' => 'HMAC-SHA1',
      'oauth_timestamp'        => Time.now.to_i.to_s,
      'oauth_nonce'            => nonce,
      'oauth_version'          => '1.0',
      'oauth_callback'         => oauth_callback(env),
      'oauth_verifier'         => oauth_verifier(env),
      'oauth_token'            => oauth_token(env)).
      map{ |(k, v)| "#{k}=\"#{escape(v)}\"" }.join(', ')

    "OAuth #{oauth}"
  end

  def attach_signature env, oauth_params
    params = reject_blank(oauth_params)
    params.merge('oauth_signature' => signature(env, params))
  end

  def signature env, params
    [Hmac.sha1("#{consumer_secret(env)}&#{oauth_token_secret(env)}",
               base_string(env, params))].pack('m').tr("\n", '')
  end

  def base_string env, oauth_params
    method   = env[REQUEST_METHOD].to_s.upcase
    base_uri = env[REQUEST_PATH]
    payload  = payload_params(env)
    query    = reject_blank(env[REQUEST_QUERY])
    params   = reject_blank(oauth_params.merge(query.merge(payload))).
      to_a.sort.map{ |(k, v)|
        "#{escape(k.to_s)}=#{escape(v.to_s)}"}.join('&')

    "#{method}&#{escape(base_uri)}&#{escape(params)}"
  end

  def nonce
    [OpenSSL::Random.random_bytes(32)].pack('m').tr("+/=\n", '')
  end

  # according to OAuth 1.0a spec, only:
  #     Content-Type: application/x-www-form-urlencoded
  # should take payload as a part of the base_string
  def payload_params env
    # if we already specified Content-Type and which is not
    # application/x-www-form-urlencoded, then we should not
    # take payload as a part of the base_string
    if env[REQUEST_HEADERS].kind_of?(Hash)  &&
       env[REQUEST_HEADERS]['Content-Type'] &&
       env[REQUEST_HEADERS]['Content-Type'] !=
         'application/x-www-form-urlencoded'
      {}

    # if it contains any binary data,
    # then it shouldn't be application/x-www-form-urlencoded either
    # the Content-Type header would be handled in our HTTP client
    elsif contain_binary?(env[REQUEST_PAYLOAD])
      {}

    # so the Content-Type header must be application/x-www-form-urlencoded
    else
      reject_blank(env[REQUEST_PAYLOAD])
    end
  end

  def reject_blank params
    params.reject{ |k, v| v.nil? || v == false ||
                                    (v.respond_to?(:strip) &&
                                     v.respond_to?(:empty) &&
                                     v.strip.empty? == true) }
  end
end
