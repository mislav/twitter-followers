atom_feed(:id => "tag:#{request.host},2009:feed", :root_url => url_for('/')) do |feed|
  feed.title "New Twitter followers"
  feed.updated @followers.first.created_at
  
  for user in @followers
    item_url = twitter_url(user)
    
    feed.entry(user, :url => item_url, :id => item_url) do |entry|
      entry.title '%s (%s)' % [user.full_name, user.screen_name]
      
      entry.content :type => 'xhtml' do |content|
        content.img :src => user.avatar_url, :width => 48, :height => 48, :alt => user.full_name
      end
    end
  end
end