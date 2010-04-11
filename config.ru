begin
  # Try to require the preresolved locked set of gems.
  require File.expand_path('../.bundle/environment', __FILE__)
rescue LoadError
  # Fall back on doing an unlocked resolve at runtime.
  require 'rubygems'
  require 'bundler'
  Bundler.setup
end

# log = File.new('log/sinatra.log', 'a')
# STDOUT.reopen(log)
# STDERR.reopen(log)

require 'app'
run Sinatra::Application
