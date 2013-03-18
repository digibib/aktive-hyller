require "pry"
require "./app"
require "date"
require 'net/smtp'

SETTINGS = YAML::load(File.open(File.join('config', 'settings.yml')))

def send_email(to, message, opts={})
  opts[:from]        ||= 'digitalutvikling@gmail.com'
  opts[:from_alias]  ||= "Digital Deichman"
  opts[:subject]     ||= "Aktive hyller statistikkrapport"

  msg = <<END_OF_MESSAGE
Content-type: text/plain; charset=UTF-8
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{to}>
Subject: #{opts[:subject]}

#{message}
END_OF_MESSAGE

  smtp = Net::SMTP.new('smtp.gmail.com', 587)
  smtp.enable_starttls
  smtp.start("gmail.com", SETTINGS["gmail"]["username"], SETTINGS["gmail"]["password"], :login) do
    smtp.send_message msg, opts[:from], to
  end
end

task :console do
  binding.pry
end

task :configure do
  cssfile = File.read("public/css/style.css")
  puts "Setting theme color"
  modified = cssfile.gsub(/(#indicator\sli.active\s*{\sbackground:\s)([^;]*)(;)/, "\\1#{SETTINGS['theme_color']}\\3")
  puts "Setting leftbar color and opacity"
  modified.gsub!(/(#left-bar\s*{\sbackground:\s)([^;]*)(;)/, "\\1#{SETTINGS['leftbar_color']}\\3")
  leftbar_regex_deactivated = /(\/\*)(background-image.+leftbar.+no-repeat;)(\*\/)/
  leftbar_regex_activated = /(background-image.+leftbar.+no-repeat;)/
  if SETTINGS['leftbar_image']
    puts "Activating leftbar image"
    modified.gsub!(leftbar_regex_deactivated, '\2')
  else
    puts "Deactivating leftbar image"
    modified.gsub!(leftbar_regex_activated, '/*\1*/')
  end
  File.open("public/css/style.css", "w") {|f| f.puts modified}
end

namespace :log do
  desc "Process log files"
  task :process do
    print "Prosessing log file.."
    %x[./log2sql.sh]
    print "OK\n"
    Rake::Task["log:stats"].execute
    Rake::Task["email:daily"].execute
  end

  desc "Clear stats.db file and create tables"
  task :setup do
    print "Creating logs/stats.db "
    %x[sqlite3 logs/stats.db < logs/schema.sql]
    print "OK\n"
  end

  desc "Generate statistics views"
  task :stats do
    print "Generating statistics.."

    # sise dag
    today = Time.now.strftime("%Y-%m-%d")
    %x[./stats.rb #{today} #{today} > logs/day.txt]
    print "day,"

    # inneværende uke
    d = Date.today - Time.now.wday + 1
    %x[./stats.rb #{d.strftime("%Y-%m-%d")} #{today} > logs/week.txt]
    print " week,"

    # inneværende måned
    d=Date.new(Time.now.year, Time.now.month, 1)
    %x[./stats.rb #{d.strftime("%Y-%m-%d")} #{today} > logs/month.txt]
    print " month "
    print "OK\n"
  end
end

namespace :email do
  task :daily do
    SETTINGS["email"]["daily"].each do |recipient|
      body = File.read('logs/day.txt')
      send_email(recipient, body)
    end
  end

  task :weekly do
    SETTINGS["email"]["weekly"].each do |recipient|
      body = File.read('logs/day.txt')
      send_email(recipient, body)
    end
  end

  task :monthly do
    SETTINGS["email"]["monthly"].each do |recipient|
      body = File.read('logs/day.txt')
      send_email(recipient, body)
    end
  end
end
