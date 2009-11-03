require 'yaml'
require 'sinatra'
require 'haml'
require 'sass'

require 'models'

set :haml, { :format => :html5 }
enable :sessions

module Egotrip
  ConfigFile = ENV['CONFIG'] || File.dirname(__FILE__) + '/config.yml'
  
  def self.config
    @config ||= YAML::load File.read(ConfigFile)
  end
  
  def self.oauth(options = {})
    Twitter::OAuth.new(config[:oauth][:key], config[:oauth][:secret], options)
  end
end


configure :development do
  DataMapper::Logger.new(STDOUT, :debug) if 'irb' == $0
  DataMapper.setup(:default, Egotrip.config[:database])
end

configure :test do
  DataMapper.setup(:default, 'sqlite3::memory:')
  DataMapper.auto_migrate!
end

helpers do
  def url_for(path)
    url = request.scheme + '://' + request.host

    if request.scheme == 'https' && request.port != 443 ||
        request.scheme == 'http' && request.port != 80
      url << ":#{request.port}"
    end

    url << path
  end
  
  def twitter_url(user)
    'http://twitter.com/' + user.screen_name
  end
  
  def link_to(text, href)
    haml_tag :a, text, :href => href
  end
  
  def logged_in?
    session[:user_id]
  end
  
  def current_user
    @current_user ||= User.get(session[:user_id])
  end
  
  def image(src)
    capture_haml { haml_tag :img, :src => src, :alt => "" }
  end
  
  def oauth_request_token(callback)
    Egotrip.oauth(:sign_in => true).tap { |oauth|
      oauth.set_callback_url(callback)
    }.request_token.tap do |token|
      session[:rtoken], session[:rsecret] = token.token, token.secret
    end
  end
  
  def oauth_authorized
    Twitter::Base.new Egotrip.oauth.tap { |oauth|
      oauth.authorize_from_request(session[:rtoken], session[:rsecret], params[:oauth_verifier])
      session.update(:atoken => oauth.access_token.token, :asecret => oauth.access_token.secret)
    }
  end
  
  def oauth_access
    Twitter::Base.new Egotrip.oauth.tap { |oauth|
      oauth.authorize_from_access(session[:atoken], session[:asecret])
    }
  end
end

get '/' do
  if logged_in?
    @followers = current_user.followers(:newest, :unprocessed)
  end
  haml :index
end

get '/login' do
  token = oauth_request_token(url_for('/authorized'))
  redirect token.authorize_url
end

get '/authorized' do
  twitter = oauth_authorized
  user = User.from_credentials(twitter.verify_credentials)
  session.update :user_id => user.id
  redirect '/'
end

get '/logout' do
  session.clear
  redirect '/'
end

post '/' do
  user = User.from_html_email(params[:html])
  nil
end

post '/approve' do
  current_user.approve(params[:user_ids], params[:block_ids], oauth_access)
  redirect '/'
end

get '/screen.css' do
  content_type 'text/css; charset=utf-8'
  sass :screen
end
