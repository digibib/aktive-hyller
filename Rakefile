require "pry"
require "./app"
require "date"
require 'net/smtp'

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

  smtp = Net::SMTP.new(SETTINGS["smtp"]["host"], SETTINGS["smtp"]["port"])
  smtp.enable_starttls if SETTINGS["smtp"]["starttls"]
  smtp.start(SETTINGS["smtp"]["domain"], SETTINGS["smtp"]["username"], SETTINGS["smtp"]["password"], SETTINGS["smtp"]["authentication"]) do
    smtp.send_message msg, opts[:from], to
  end
end

task :console do
  binding.pry
end

namespace :setup do
  desc "Install and setup on Ubuntu system"
  task :install do
    puts "installing automated start scripts for firefox and xscreensaver"
    %x[mkdir -p ~/.config/autostart]
    %x[ln -s ~/.config/autostart/aktivehyller.desktop scripts/aktivehyller.desktop && ln -s ~/.config/autostart/xscreensaver-timeout.desktop scripts/xscreensaver-timeout.desktop]
    
    puts "installing foreman and generating Procfile"
    %x[gem install foreman]
    `cat <<EOF | tee ~/code/Procfile
    app: ~/.rvm/scripts/rvm; cd ~/code/aktive-hyller; ruby app.rb
    rfid: sleep 3; ~/.rvm/scripts/rvm; cd ~/code/rfidgeek; ruby rfid.rb
    EOF`
   
   puts "installing upstart file"
   %x[rvmsudo foreman export upstart /etc/init -a aktivehyller -p 4567 -u aktiv -l ~/code/aktive-hyller/logs/upstart]
   puts "modifying upstart to automatic start on all run levels"
   
   `rvmsudo sed -i '/started\ network-interface/ a\
           new line string' /etc/init/aktivehyller.conf`
   puts "Setting up logs"
   Rake::Task["log:setup"].invoke
   puts "activating cron tasks for log"
   %x[rvmsudo ln -s /etc/cron.d/aktivehyller-cronjobs scripts/aktivehyller-cronjobs]
   puts "Done. Now setup config files (config/settings.yml) and run Rake configure"
  end
  
  desc "Configure CSS"
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
end

namespace :log do
  desc "Process log files"
  task :process do
    print "Prosessing log file.."
    %x[./scripts/log2sql.sh]
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
    %x[./scripts/stats.rb #{today} #{today} > logs/daily.txt]
    print "day,"

    # inneværende uke
    d = Date.today - Time.now.wday + 1
    %x[./scripts/stats.rb #{d.strftime("%Y-%m-%d")} #{today} > logs/weekly.txt]
    print " week,"

    # inneværende måned
    d=Date.new(Time.now.year, Time.now.month, 1)
    %x[./scripts/stats.rb #{d.strftime("%Y-%m-%d")} #{today} > logs/monthly.txt]
    print " month "
    print "OK\n"
  end
end

namespace :email do
  task :daily do
    SETTINGS["email"]["daily"].each do |recipient|
      body = File.read('logs/daily.txt')
      send_email(recipient, body)
    end
  end

  task :weekly do
    SETTINGS["email"]["weekly"].each do |recipient|
      body = File.read('logs/weekly.txt')
      send_email(recipient, body)
    end
  end

  task :monthly do
    SETTINGS["email"]["monthly"].each do |recipient|
      body = File.read('logs/monthly.txt')
      send_email(recipient, body)
    end
  end
end
