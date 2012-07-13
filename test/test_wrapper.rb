
require 'rest-core/test'

describe RC::Wrapper do
  should 'wrap around simple middleware' do
    wrapper = RC::Bypass.dup
    wrapper.send(:include, RC::Wrapper)
    client = RC::Builder.client do
      use wrapper do
        use RC::Bypass
      end
      run RC::Dry
    end

    client.new.app.call(1=>2){ |res| res.should.eq(1=>2) }
  end

  should 'default app is RestCore::Dry' do
    wrapper = Class.new
    wrapper.send(:include, RC::Wrapper)
    wrapper.new.wrapped.class.should.eq RC::Dry
  end

  should 'switch default_app to RestCore::RestClient' do
    wrapper = Class.new
    wrapper.send(:include, RC::Wrapper)
    wrapper.default_app = RC::RestClient
    wrapper.new.wrapped.class.should.eq RC::RestClient
  end
end
