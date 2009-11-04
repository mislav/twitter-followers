# remove extlib's "Mash"
Object.send(:remove_const, :Mash) if defined? ::Mash
# twitter loads the "mash" gem
require 'twitter'

# fix for Mash v0.0.3
Mash.class_eval do
  def stringify_keys() self end
end

require 'rack/request'

class Twitter::OAuthLogin
  attr_reader :options
  
  DEFAULTS = {
    :login_path => '/login', :return_to => '/',
    :site => 'http://twitter.com',
    :authorize_path => '/oauth/authenticate'
  }
  
  def initialize(app, options)
    @app = app
    @options = DEFAULTS.merge options
  end
  
  def call(env)
    request = Request.new(env)
    
    if request.get? and request.path == options[:login_path]
      if request[:oauth_verifier]
        handle_twitter_authorization(request) do
          @app.call(env)
        end
      else
        redirect_to_twitter(request)
      end
    else
      @app.call(env)
    end
  end
  
  module Helpers
    def twitter_consumer
      token = OAuth::AccessToken.new(oauth_consumer, *session[:access_token])
      Twitter::Base.new token
    end
    
    def oauth_consumer
      OAuth::Consumer.new(*session[:oauth_consumer])
    end
    
    def twitter_user
      request.env['twitter.authenticated_user']
    end
  end
  
  class Request < Rack::Request
    # holds :request_token, :access_token
    def session
      env['rack.session'] ||= {}
    end
    
    # SUCKS: must duplicate logic from `url` method
    def url_for(path)
      url = scheme + '://' + host

      if scheme == 'https' && port != 443 ||
          scheme == 'http' && port != 80
        url << ":#{port}"
      end

      url << path
    end
  end
  
  protected
  
  def redirect_to_twitter(request)
    token = oauth_consumer.get_request_token(:oauth_callback => request.url)
    request.session[:request_token] = [token.token, token.secret]
    redirect token.authorize_url
  end
  
  def handle_twitter_authorization(request)
    request_token = ::OAuth::RequestToken.new(oauth_consumer, *request.session[:request_token])
    access_token = request_token.get_access_token(:oauth_verifier => request[:oauth_verifier])
    
    request.session.delete(:request_token)
    request.session[:access_token] = [access_token.token, access_token.secret]
    consumer = access_token.consumer
    request.session[:oauth_consumer] = [consumer.key, consumer.secret, consumer.options]
    
    twitter = Twitter::Base.new access_token
    request.env['twitter.authenticated_user'] = twitter.verify_credentials
    
    response = yield
    
    if response[0].to_i == 404
      redirect request.url_for(options[:return_to])
    else
      response
    end
  end
  
  def redirect(url)
    ["302", {'Location' => url, 'Content-type' => 'text/plain'}, []]
  end
  
  def oauth_consumer
    ::OAuth::Consumer.new options[:key], options[:secret],
      :site => options[:site], :authorize_path => options[:authorize_path]
  end
end
