railsrc = File.expand_path('.railsrc', ENV['HOME'])
load railsrc if File.exist?(railsrc)
