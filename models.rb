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
  
  def self.from_html_email(html)
    doc = Nokogiri::HTML html
    attributes = parse_attributes(doc)
    user = first_or_create({:screen_name => attributes[:screen_name]}, attributes)
    user.follows.create :target => User.first(:screen_name => 'mislav')
    user
  end
  
  def self.parse_attributes(doc)
    a = {}
    a[:avatar_url] = doc.at('img[width="48px"]')['src'].to_s
    
    user_title = doc.at('a[href*="utm_source=follow"]').inner_text
    _, a[:full_name], a[:screen_name] = user_title.match(/(.+) \((.+?)\)$/).to_a
    
    a[:followers_count], a[:tweets_count], a[:following_count] = doc.search('//td/span/span').map { |info|
      info.inner_text.scan(/\d+/).first.to_i
    }
    
    attributes
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
