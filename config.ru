require 'rubygems'
gem 'dm-core', '~> 0.10.1'
gem 'dm-timestamps', '~> 0.10.1'
gem 'haml', '~> 2.2.9'

log = File.new('log/sinatra.log', 'a')
STDOUT.reopen(log)
STDERR.reopen(log)

require 'app'
run Sinatra::Application
