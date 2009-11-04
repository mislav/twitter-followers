ENV['RACK_ENV'] = 'test'
require 'app'
require 'rack/mock'
require 'rack/utils'

require 'fakeweb'
FakeWeb.allow_net_connect = false

describe "application" do
  before(:each) do
    @request = Rack::MockRequest.new(Sinatra::Application)
  end
  
  def response
    @response
  end
  
  it "should create new follower" do
    mislav = User.first_or_create(:screen_name => 'mislav')
    params = YAML.load(File.open('test_email_payload.yml'))
    
    post('/', :lint => true, :input => Rack::Utils.build_query(params))
    response.body.should be_empty
    
    follower = User.last
    follower.screen_name.should == 'miamicandy5'
    follower.full_name.should == 'candy hide'
    follower.followers_count.should == 4
    follower.following_count.should == 187
    follower.tweets_count.should == 1
    follower.avatar_url.should == 'http://a3.twimg.com/profile_images/482835659/1haybn_normal.jpg'
    
    follow = follower.follows.first
    follow.blocked.should be_nil
    follow.target.should == mislav
  end
  
  it "should login with Twitter" do
    consumer = mock_oauth_consumer('OAuth Consumer')
    token = mock('Request Token', :authorize_url => 'http://disney.com/oauth', :token => 'abc', :secret => '123')
    consumer.should_receive(:get_request_token).with(:oauth_callback => 'http://example.org/login').and_return(token)
    # request.session[:request_token] = token
    # redirect token.authorize_url
    
    get('/login', :lint => true)
    response.status.should == 302
    response['Location'].should == 'http://disney.com/oauth'
    response.body.should be_empty
    session[:request_token].should == ['abc', '123']
  end
  
  it "should authorize with Twitter" do
    consumer = mock_oauth_consumer('OAuth Consumer', :key => 'con', :secret => 'sumer', :options => {:one=>'two'})
    request_token = mock('Request Token')
    OAuth::RequestToken.should_receive(:new).with(consumer, 'abc', '123').and_return(request_token)
    access_token = mock('Access Token', :token => 'access1', :secret => '42', :consumer => consumer)
    request_token.should_receive(:get_access_token).with(:oauth_verifier => 'abc').and_return(access_token)
    
    twitter = mock('Twitter Base')
    Twitter::Base.should_receive(:new).with(access_token).and_return(twitter)
    user_credentials = { :screen_name => 'faker',
      :name => 'Fake Jr.', :profile_image_url => 'http://disney.com/mickey.png',
      :followers_count => '13', :friends_count => '6', :statuses_count => '52' }
    twitter.should_receive(:verify_credentials).and_return(user_credentials.to_mash)
    
    session_data = {:request_token => ['abc', '123']}
    get('/login?oauth_verifier=abc', build_session(session_data).update(:lint => true))
    response.status.should == 302
    response['Location'].should == 'http://example.org/'
    session[:request_token].should be_nil
    session[:access_token].should == ['access1', '42']
    session[:oauth_consumer].should == ['con', 'sumer', {:one=>'two'}]
    
    current_user = User.last
    current_user.screen_name.should == 'faker'
  end
  
  it "should approve or block" do
    mislav = User.first_or_create(:screen_name => 'mislav')
    follower1 = User.create(:screen_name => 'follower1')
    follower1.follows.create(:target => mislav)
    follower2 = User.create(:screen_name => 'follower2')
    follower2.follows.create(:target => mislav)
    
    mock_oauth_consumer('Twitter Base')
    params = { 'user_ids[]' => [follower1.id, follower2.id] }
    post('/approve', build_session(:user_id => mislav.id).update(:lint => true, :input => Rack::Utils.build_query(params)))
    
    mislav.followings(:user_id => [follower1.id, follower2.id]).map { |f| f.blocked }.should == [false, false]
  end
  
  [:get, :post, :put, :delete, :head].each do |method|
    class_eval("def #{method}(*args) @response = @request.#{method}(*args) end")
  end
  
  def session
    @session ||= begin
      escaped = response['Set-Cookie'].match(/\=(.+?);/)[1]
      cookie_load Rack::Utils.unescape(escaped)
    end
  end
  
  def build_session(data)
    encoded = cookie_dump(data)
    { 'HTTP_COOKIE' => Rack::Utils.build_query('rack.session' => encoded) }
  end
  
  def cookie_load(encoded)
    decoded = encoded.unpack('m*').first
    Marshal.load(decoded)
  end
  
  def cookie_dump(obj)
    [Marshal.dump(obj)].pack('m*')
  end
  
  def mock_oauth_consumer(*args)
    consumer = mock(*args)
    OAuth::Consumer.should_receive(:new).and_return(consumer)
    # .with(instance_of(String), instance_of(String),
    # :site => 'http://twitter.com', :authorize_path => '/oauth/authenticate')
    consumer
  end
end
