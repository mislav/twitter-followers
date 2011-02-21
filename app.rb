require 'sinatra'
require 'haml'
require 'sass'
require 'builder'
require 'choices'

require 'models'

set :haml, { :format => :html5 }

Choices.load_settings(File.join(settings.root, 'config.yml'), settings.environment.to_s).each do |key, value|
  set key.to_sym, value
end

enable :sessions
require 'twitter/login'
use Twitter::Login, :consumer_key => settings.twitter.consumer_key, :secret => settings.twitter.secret
helpers Twitter::Login::Helpers

configure do
  DataMapper::Logger.new(STDOUT, :debug) if 'irb' == $0
  DataMapper.setup(:default, settings.database.url)
  DataMapper.auto_migrate! if :test == settings.environment
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
    "http://twitter.com/#{user.screen_name}"
  end
  
  def link_to(text, href, attrs = {})
    haml_tag :a, text, attrs.merge(:href => href)
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
  if logged_in?
    load_followers
    @new_user = current_user.followings.count.zero?
  end
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
  user = User.from_html_email(params[:html], params[:headers])
  nil
end

post '/approve' do
  requires_login!
  current_user.approve(params[:user_ids], params[:block_ids], twitter_client)
  redirect url_for('/')
end

get '/screen.css' do
  sass :screen
end

get '/users/:user.xml' do
  content_type 'application/atom+xml', :charset => 'utf-8'
  user = User.first(:screen_name => params[:user])
  @followings = user.followings.newest.unprocessed
  builder :feed
end

get '/users/:user' do
  @user = User.first(:screen_name => params[:user])
  @tweets = begin
    twitter_client.user_timeline(:screen_name => @user.screen_name)
  rescue Twitter::Unauthorized
    []
  end
  haml :user_info, :layout => false
end
