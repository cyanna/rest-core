
require 'uri'
require 'rest-core'

module RestCore::Middleware
  include RestCore

  def self.included mod
    mod.send(:include, RestCore)
    mod.send(:attr_reader, :app)
    mem = if mod.respond_to?(:members) then mod.members else [] end
    src = mem.map{ |member| <<-RUBY }
      def #{member} env
        if    env.key?('#{member}')
          env['#{member}']
        else
              @#{member}
        end
      end
    RUBY
    args      = [:app] + mem
    para_list = args.map{ |a| "#{a}=nil"}.join(', ')
    args_list = args                     .join(', ')
    ivar_list = args.map{ |a| "@#{a}"   }.join(', ')
    src << <<-RUBY
      def initialize #{para_list}
        #{ivar_list} = #{args_list}
      end
    RUBY
    accessor = Module.new
    accessor.module_eval(src.join("\n"), __FILE__, __LINE__)
    mod.const_set(:Accessor, accessor)
    mod.send(:include, accessor)
  end

  def call env, &k; app.call(env, &(k || id)); end
  def id          ; RC.id                    ; end
  def fail env, obj
    if obj
      env.merge(FAIL => (env[FAIL] || []) + [obj])
    else
      env
    end
  end
  def log env, obj
    if obj
      env.merge(LOG  => (env[LOG]  || []) + [obj])
    else
      env
    end
  end
  def run app=app
    if app.respond_to?(:app) && app.app
      run(app.app)
    else
      app
    end
  end

  module_function
  def request_uri env
    # compacting the hash
    if (query = (env[REQUEST_QUERY] || {}).select{ |k, v| v }).empty?
      env[REQUEST_PATH].to_s
    else
      q = if env[REQUEST_PATH] =~ /\?/ then '&' else '?' end
      "#{env[REQUEST_PATH]}#{q}#{percent_encode(query)}"
    end
  end
  public :request_uri

  def percent_encode query
    query.sort.map{ |(k, v)|
      if v.kind_of?(Array)
        v.map{ |vv| "#{escape(k.to_s)}=#{escape(vv.to_s)}" }.join('&')
      else
        "#{escape(k.to_s)}=#{escape(v.to_s)}"
      end
    }.join('&')
  end
  public :percent_encode

  UNRESERVED = /[^a-zA-Z0-9\-\.\_\~]/
  def escape string
    URI.escape(string, UNRESERVED)
  end
  public :escape

  def contain_binary? payload
    return false unless payload
    return true  if     payload.respond_to?(:read)
    return true  if     payload.find{ |k, v|
      # if payload is an array, then v would be nil
      (v || k).respond_to?(:read) ||
      # if v is an array, it could contain binary data
      (v.kind_of?(Array) && v.any?{ |vv| vv.respond_to?(:read) }) }
    return false
  end
  public :contain_binary?

  def string_keys hash
    hash.inject({}){ |r, (k, v)|
      if v.kind_of?(Hash)
        r[k.to_s] = case k.to_s
                      when REQUEST_QUERY, REQUEST_PAYLOAD, REQUEST_HEADERS
                        string_keys(v)
                      else;         v
                    end
      else
        r[k.to_s] = v
      end
      r
    }
  end
  public :string_keys

  # this method is intended to merge payloads if they are non-empty hashes,
  # but prefer the right most one if they are not hashes.
  def merge_hash a, b
    if b.respond_to?(:empty?) && b.empty?
      Middleware.string_keys(a)
    elsif a.respond_to?(:merge)
      if b.respond_to?(:merge)
        Middleware.string_keys(a).merge(Middleware.string_keys(b))
      else
        Middleware.string_keys(b)
      end
    else
      Middleware.string_keys(b)
    end
  end
  public :merge_hash
end
