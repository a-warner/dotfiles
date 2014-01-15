require 'irb/completion'
require 'irb/ext/save-history'

IRB.conf[:AUTO_INDENT] = true
IRB.conf[:SAVE_HISTORY] = 200
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-history"

railsrc = File.expand_path('.railsrc', ENV['HOME'])
load railsrc if File.exist?(railsrc) || File.symlink?(railsrc)
