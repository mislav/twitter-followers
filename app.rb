require 'yaml'
require 'sinatra'

require 'dm-core'
require 'dm-timestamps'
require 'models'

require 'haml'
require 'sass'
require 'nokogiri'

set :haml, { :format => :html5 }

configure do
  config_file = ENV['CONFIG'] || File.dirname(__FILE__) + '/config.yml'
  config = YAML::load File.read(config_file)
  
  dbconfig = config[:database]
  adapter = DataMapper.setup(:default, dbconfig)
  
  if ':memory:' == adapter.options['path']
    DataMapper.auto_migrate!
  end
end

helpers do
  def twitter_url(user)
    "http://twitter.com/#{user.screen_name}"
  end
  
  def link_to(text, href)
    haml_tag :a, text, :href => href
  end
end

get '/' do
  @users = User.all
  haml :index
end

post '/' do
  user = User.from_html_email params[:html]
  nil
end

get '/screen.css' do
  content_type 'text/css; charset=utf-8'
  sass :screen
end
