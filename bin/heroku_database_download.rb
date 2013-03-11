#!/usr/bin/env ruby

require 'optparse'

def run_command(command)
  `#{command} 2>&1`.tap do |result|
    unless $? == 0
      puts "Error running command #{command}, errors:\n #{result}"
      exit 1
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-a", "--app [APPLICATION]", "Heroku app") do |app|
    options[:app] = app
  end

  opts.on("-l", "--location LOCATION", "Where to put the database dump (required)") do |loc|
    options[:location] = loc
  end
end.parse!

unless options[:location] && File.directory?(location = File.expand_path(options[:location]))
  puts "Missing argument location"
  exit 1
end

backups_cmd = "heroku pgbackups:url"
backups_cmd << " --app #{options[:app]}" if options[:app]

threads = []
filenames = run_command(backups_cmd).split("\n").map do |url|
  "/tmp/#{url[%r{heroku.com/(.+?)\?}, 1]}".tap do |tmp_filename|
    puts "Downloading #{url} to #{tmp_filename}..."
    threads << Thread.new { run_command "wget -O #{tmp_filename} \"#{url}\"" }
  end
end

dump_filename = File.join(location, "#{Time.now.strftime('%Y-%m-%d')}.dump")

begin
  threads.each(&:join)

  puts "Joining files into #{dump_filename}..."
  run_command "cat #{filenames.join(" ")} > \"#{dump_filename}\""
ensure
  filenames.each do |f|
    puts "Cleaning up #{f}..."
    File.delete(f)
  end
end

puts "Successfully downloaded to #{dump_filename}"
