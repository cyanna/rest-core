
source 'https://rubygems.org/'

gemspec

gem 'rest-client'

gem 'rake'
gem 'bacon'
gem 'muack'
gem 'webmock'

gem 'json'
gem 'json_pure'
gem 'multi_json'

gem 'rack'
gem 'ruby-hmac'

platforms :ruby do
  gem 'yajl-ruby'
end

platforms :rbx do
  gem 'rubysl-weakref'    # used in rest-core
  gem 'rubysl-singleton'  # used in rake
  gem 'rubysl-rexml'      # used in crack used in webmock
  gem 'rubysl-bigdecimal' # used in crack used in webmock
end

platforms :jruby do
  gem 'jruby-openssl'
end
