
require 'digest/md5'

require 'rest-core/util/parse_query'
require 'rest-core/util/json'

module RestCore
  module ClientOauth1
    def authorize_url! opts={}
      self.data = ParseQuery.parse_query(
        post(request_token_path, {}, {},
             {:json_response => false}.merge(opts)))

      authorize_url
    end

    def authorize_url
      url(authorize_path, :oauth_token => oauth_token)
    end

    def authorize! opts={}
      self.data = ParseQuery.parse_query(
        post(access_token_path, {}, {},
             {:json_response => false}.merge(opts)))

      data['authorized'] = 'true'
      data
    end

    def authorized?
      !!(oauth_token && oauth_token_secret && data['authorized'])
    end

    def data_json
      Json.encode(data.merge('sig' => calculate_sig))
    end

    def data_json= json
      self.data = check_sig_and_return_data(Json.decode(json))
    rescue Json.const_get(:ParseError)
      self.data = nil
    end

    def oauth_token
      data['oauth_token'] if data.kind_of?(Hash)
    end
    def oauth_token= token
      data['oauth_token'] = token if data.kind_of?(Hash)
    end
    def oauth_token_secret
      data['oauth_token_secret'] if data.kind_of?(Hash)
    end
    def oauth_token_secret= secret
      data['oauth_token_secret'] = secret if data.kind_of?(Hash)
    end
    def oauth_callback
      data['oauth_callback'] if data.kind_of?(Hash)
    end
    def oauth_callback= uri
      data['oauth_callback'] = uri if data.kind_of?(Hash)
    end

    private
    def default_data
      {}
    end

    def check_sig_and_return_data hash
      hash if consumer_secret && hash.kind_of?(Hash) &&
              calculate_sig(hash) == hash['sig']
    end

    def calculate_sig hash=data
      base = hash.reject{ |(k, _)| k == 'sig' }.sort.map{ |(k, v)|
        "#{Middleware.escape(k.to_s)}=#{Middleware.escape(v.to_s)}"
      }.join('&')
      Digest::MD5.hexdigest("#{Middleware.escape(consumer_secret)}&#{base}")
    end
  end
end
