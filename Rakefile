task :environment do
  require 'app'
end

namespace :db do
  task :migrate => [:environment] do
    DataMapper.auto_migrate!
  end
end
