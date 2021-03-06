require "pry"
require "./app"
require "date"
require 'net/smtp'

def send_email(to, message, opts={})
  opts[:from]        ||= 'digitalutvikling@gmail.com'
  opts[:from_alias]  ||= "Digital Deichman"
  opts[:subject]     ||= "Aktive hyller statistikkrapport"
  ip = %x[ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}']
  msg = <<END_OF_MESSAGE
Content-type: text/plain; charset=UTF-8
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{to}>
Subject: #{opts[:subject]} for '#{SETTINGS["name"]}' IP: #{ip}

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
    pwd  = File.dirname(__FILE__)
    home = ENV['HOME']
    
    puts "installing automated start scripts for firefox and xscreensaver"
    %x[mkdir -p #{home}/.config/autostart]
    %x[ln -s #{pwd}/scripts/aktivehyller.desktop #{home}/.config/autostart/aktivehyller.desktop ]
    %x[ln -s #{pwd}/scripts/xscreensaver-timeout.desktop #{home}/.config/autostart/xscreensaver-timeout.desktop ]

    puts "generating foreman Procfile"
    `cat <<EOF | tee #{home}/code/Procfile
app: #{home}/.rvm/scripts/rvm; cd #{pwd}; bundle exec ruby app.rb
rfid: sleep 3; #{home}/.rvm/scripts/rvm; cd #{home}/code/rfidgeek; bundle exec ruby rfid.rb
EOF`
   
   puts "Installing required gems via bundler"
   puts "Bundling rfidgeek"
   %x[cd #{home}/code/rfidgeek && bundle ]
   puts "Bundling aktive-hyller"
   %x[cd #{home}/code/aktive-hyller && bundle ]
   
   puts "installing upstart file"
   %x[rvmsudo foreman export upstart /etc/init -f #{home}/code/Procfile -a aktivehyller -p 4567 -u aktiv -l #{pwd}/logs/upstart]

   #puts "modifying upstart to automatic start on all run levels"
   #`rvmsudo sed -i '/started\ network-interface/a\ \ and runlevel[2345]' /etc/init/aktivehyller.conf`
   #`rvmsudo sed -i '/stopping\ network-interface/a\ \ and runlevel[016]' /etc/init/aktivehyller.conf`
   puts "Setting up logs"
   Rake::Task["log:setup"].invoke
   puts "activating cron tasks for log (must be root)"
   %x[rvmsudo chown root.root #{pwd}/scripts/aktivehyller-cronjobs && rvmsudo ln -s #{pwd}/scripts/aktivehyller-cronjobs /etc/cron.d/aktivehyller-cronjobs ]
   puts "Done.\n\n Now setup config files (#{pwd}/config/settings.yml) and run:\nrake setup:configure"
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
    puts "linking orange star images"
    %x[ln -s #{pwd}/public/img/star_half_orange.png #{pwd}/public/img/star_half.png ]
    %x[ln -s #{pwd}/public/img/star_whole_orange.png #{pwd}/public/img/star_whole.png ]
    puts "Done.\n\n Now do remaining changes in Firefox browser"
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
