ENV['RACK_ENV'] = 'test'
require 'app'
require 'rack/mock'

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
    follow.created_at.to_time.utc.to_s.should == 'Wed Jan 27 09:02:08 UTC 2010'
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
  
  protected
  
  [:get, :post, :put, :delete, :head].each do |method|
    class_eval("def #{method}(*args) @response = @request.#{method}(*args) end")
  end
  
  def session
    @session ||= begin
      escaped = response['Set-Cookie'].match(/\=(.+?);/)[1]
      cookie_load Rack::Utils.unescape(escaped)
    end
  end
  
  private
  
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
