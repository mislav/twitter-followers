require 'yaml'
require 'sinatra'
require 'twitter'

require 'dm-core'
require 'dm-timestamps'
require 'models'

require 'haml'
require 'sass'
require 'nokogiri'

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

configure do
  dbconfig = Egotrip.config[:database]
  adapter = DataMapper.setup(:default, dbconfig)
  
  if ':memory:' == adapter.options['path']
    DataMapper.auto_migrate!
  end
end

helpers do
  def url_for(path)
    url = request.scheme + "://"+ request.host

    if request.scheme == "https" && request.port != 443 ||
        request.scheme == "http" && request.port != 80
      url << ":#{request.port}"
    end

    url << path
  end
  
  def twitter_url(user)
    "http://twitter.com/#{user.screen_name}"
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
end

get '/' do
  @users = User.all
  haml :index
end

get '/login' do
  oauth = Egotrip.oauth(:sign_in => true)
  oauth.set_callback_url url_for('/authorized')
  token = oauth.request_token
  session[:rtoken], session[:rsecret] = token.token, token.secret
  redirect token.authorize_url
end

get '/logout' do
  session[:user_id] = nil
  redirect '/'
end

get '/authorized' do
  rtoken, rsecret = session[:rtoken], session[:rsecret]
  oauth = Egotrip.oauth
  oauth.authorize_from_request rtoken, rsecret, params[:oauth_verifier]
  twitter = Twitter::Base.new(oauth)
  cred = twitter.verify_credentials
  
  user = User.first_or_create({:screen_name => cred.screen_name}, {
    :full_name => cred.name, :avatar_url => cred.profile_image_url,
    :followers_count => cred.followers_count, :following_count => cred.friends_count,
    :tweets_count => cred.statuses_count
  })
  session[:user_id] = user.id
  
  redirect '/'
end

post '/' do
  user = User.from_html_email params[:html]
  nil
end

get '/screen.css' do
  content_type 'text/css; charset=utf-8'
  sass :screen
end
