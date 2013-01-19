require 'irb/completion'

IRB.conf[:IRB_RC] = lambda do |*args|
  railsrc = File.expand_path('.railsrc', ENV['HOME'])
  load railsrc if File.exist?(railsrc)
end
