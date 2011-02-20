require 'uri'
require 'net/http'
require 'crack/json'
require 'dm-core'
require 'dm-timestamps'
require 'nokogiri'

class User
  include DataMapper::Resource
  
  has n, :follows
  has n, :followings, :model => 'Follow', :child_key => [:target_id]
  
  def following(*scopes)
    scopes.inject(follows) { |scope, name| scope.send(name) }.map { |f| f.target }
  end
  
  def followers(*scopes)
    scopes.inject(followings) { |scope, name| scope.send(name) }.map { |f| f.user }
  end
  
  property :id,           Serial
  property :screen_name,  String
  property :full_name,    String
  property :created_at,   DateTime
  property :updated_at,   DateTime
  property :avatar_url,   String,   :length => 255
  property :followers_count,  Integer
  property :following_count,  Integer
  property :tweets_count,     Integer
  
  def self.newest
    all(:order => [ :created_at.desc ])
  end
  
  def self.from_twitter(user)
    first_or_create({:screen_name => user.screen_name}, {
      :full_name => user.name, :avatar_url => user.profile_image_url,
      :followers_count => user.followers_count, :following_count => user.friends_count,
      :tweets_count => user.statuses_count
    })
  end
  
  def self.from_html_email(html, headers)
    return unless headers['x-twitteremailtype'] == 'is_following'
    # FIXME: use x-twitterrecipientid
    recipient = headers['x-twitterrecipientscreenname']
    target = User.first(:screen_name => recipient)
    followed_at = Time.parse headers['x-twittercreatedat']
    
    attributes = {
      :screen_name => headers['x-twittersenderscreenname'],
      :full_name => headers['x-twittersendername']
    }
    
    attributes.update parse_attributes(Nokogiri::HTML(html))
    
    user = first_or_create({:screen_name => attributes[:screen_name]}, attributes)
    user.follows.create :target => target, :created_at => followed_at
    user
  end
  
  def self.parse_attributes(doc)
    Hash.new.tap do |a|
      a[:avatar_url] = doc.at('img[width="48"]/@src').to_s
    
      a[:tweets_count], a[:following_count], a[:followers_count] = \
        doc.search('table[style*="margin:10px"] > tr:first-child > td').map { |info|
          info.inner_text.scan(/\d+/).first.to_i
        }
    end
  end
  
  def approve(user_ids, block_ids, twitter)
    user_ids = Array(user_ids).map { |id| id.to_i }
    block_ids = Array(block_ids).map { |id| id.to_i }
    
    # fix for a strange issue in DataMapper 0.10.1 where
    # it complains that `user_id` is not property of Follow
    Follow.last.user
    
    self.followings(:user_id => user_ids).each do |follow|
      if follow.blocked = block_ids.include?(follow.user.id)
        name = follow.user.screen_name
        begin
          twitter.block name
        rescue
          warn "Error while blocking #{name} (#{$!.class}): #{$!}"
        end
      end
      follow.save
    end
  end
  
  def tweetblocker_grade
    body = Net::HTTP.get(URI("http://tweetblocker.com/api/username/#{screen_name}.json"))
    result = Hashie::Mash.new Crack::JSON.parse(body)
    result.candidate.grade
  end
end

class Follow
  include DataMapper::Resource
  
  belongs_to :user
  belongs_to :target, :model => 'User'
  
  property :id,         Serial
  property :created_at, DateTime
  property :blocked,    Boolean
  
  def self.newest
    all(:order => [ :created_at.desc ])
  end
  
  def self.unprocessed
    all(:blocked => nil)
  end
  
  def self.blocked
    all(:blocked => true)
  end
  
  def self.approved
    all(:blocked => false)
  end
end
