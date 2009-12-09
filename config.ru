require 'vendor/gems/environment'
if defined?(Gem) and not Gem.respond_to?(:dir)
  def Gem.dir
    @dir ||= File.expand_path(File.dirname(__FILE__)) + '/vendor/gems'
  end
end

log = File.new('log/sinatra.log', 'a')
STDOUT.reopen(log)
STDERR.reopen(log)

require 'app'
run Sinatra::Application
