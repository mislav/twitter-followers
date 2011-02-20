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
    follower.screen_name.should == 'moorko'
    follower.full_name.should == 'Moorko Mooric'
    follower.followers_count.should == 70
    follower.following_count.should == 94
    follower.tweets_count.should == 644
    follower.avatar_url.should == 'http://a3.twimg.com/profile_images/358095107/jon_jondruse.com_62f098fa_normal.jpg'
    
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
    
    mock_twitter_consumer('Twitter Base')
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
  
  def mock_twitter_consumer(*args)
    mock_oauth = mock
    mock_oauth.should_receive(:authorize_from_access)
    Twitter::OAuth.should_receive(:new).and_return(mock_oauth)
    consumer = mock(*args)
    Twitter::Base.should_receive(:new).with(mock_oauth).and_return(consumer)
    consumer
  end
end
