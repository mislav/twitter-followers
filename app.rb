require 'yaml'
require 'sinatra'
require 'haml'
require 'sass'
require 'builder'

require 'models'

set :haml, { :format => :html5 }

module Egotrip
  def self.config_file
    @config_file ||= ENV['CONFIG'] || File.dirname(__FILE__) + '/config.yml'
  end
  
  def self.config
    @config ||= File.exists?(config_file) ? YAML::load(File.read(config_file)) : {}
  end
end

enable :sessions
require 'oauth_login'
use Twitter::OAuthLogin, :key => Egotrip.config[:oauth][:key], :secret => Egotrip.config[:oauth][:secret]
helpers Twitter::OAuthLogin::Helpers

configure :development, :production do
  DataMapper::Logger.new(STDOUT, :debug) if 'irb' == $0
  DataMapper.setup(:default, Egotrip.config[:database])
end

configure :test do
  DataMapper.setup(:default, 'sqlite3::memory:')
  DataMapper.auto_migrate!
end

require 'date'
DateTime.class_eval do
  def xmlschema
    strftime("%Y-%m-%dT%H:%M:%S%Z")
  end unless instance_methods.map {|m| m.to_sym }.include? :xmlschema
end

require 'action_view/helpers/atom_feed_helper'
helpers ActionView::Helpers::AtomFeedHelper

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
  
  def image(src, attrs = {})
    capture_haml do
      haml_tag :img, {:src => src, :alt => ""}.update(attrs)
    end
  end
  
  def logged_in?
    session[:user_id]
  end
  
  def requires_login!
    halt 401 unless logged_in?
  end
  
  def current_user
    @current_user ||= User.get(session[:user_id])
  end
  
  def load_followers(user = current_user)
    @followers = user.followers(:newest, :unprocessed)
  end
end

get '/' do
  load_followers if logged_in?
  haml :index
end

get '/login' do
  user = User.from_twitter(twitter_user)
  session[:user_id] = user.id
  redirect url_for('/')
end

get '/logout' do
  twitter_logout
  session.delete(:user_id)
  redirect url_for('/')
end

post '/' do
  user = User.from_html_email(params[:html])
  nil
end

post '/approve' do
  requires_login!
  current_user.approve(params[:user_ids], params[:block_ids], twitter_consumer)
  redirect url_for('/')
end

get '/screen.css' do
  content_type 'text/css; charset=utf-8'
  sass :screen
end

get '/feed.xml' do
  content_type 'application/atom+xml; charset=utf-8'
  load_followers(User.first(:screen_name => 'mislav'))
  builder :feed
end
