class User
  include DataMapper::Resource

  property :id,           Serial
  property :screen_name,  String
  property :full_name,    String
  property :created_at,   DateTime
  property :updated_at,   DateTime
  property :avatar_url,   String,   :length => 255
  property :followers,    Integer
  property :following,    Integer
  property :tweets,       Integer
  
  def self.newest
    all(:order => [ :created_at.desc ])
  end
  
  def self.from_html_email(html)
    doc = Nokogiri::HTML html
    attributes = parse_attributes(doc)
    user = first_or_create({:screen_name => attributes[:screen_name]}, attributes)
  end
  
  def self.parse_attributes(doc)
    attributes = {}
    attributes[:avatar_url] = doc.at('img[width="48px"]')['src'].to_s
    
    user_title = doc.at('a[href*="utm_source=follow"]').inner_text
    _, attributes[:full_name], attributes[:screen_name] = user_title.match(/(.+) \((.+?)\)$/).to_a
    
    attributes[:followers], attributes[:tweets], attributes[:following] = doc.search('//td/span/span').map { |info|
      info.inner_text.scan(/\d+/).first.to_i
    }
    
    attributes
  end
end
