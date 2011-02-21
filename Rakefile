task :spec do
  exec(*%w[bundle exec ruby app_spec.rb --color])
end

task :environment do
  require 'app'
end

namespace :db do
  task :migrate => [:environment] do
    DataMapper.auto_upgrade!
  end
  
  task :pull do
    system %(ssh mislav 'pg_dump -Fc -Ox twitter' | pg_restore -d egotrip -c)
  end
end
