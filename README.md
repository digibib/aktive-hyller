# Aktive hyller Setup and Configuration

## Linux install for Aktive Hyller
Install lubuntu 12.04 LTS or newer. 13.04 is recommended for best driver support.

update and install necessary packages:

### Remote management

```bash
sudo apt-get update && sudo apt-get upgrade
sudo apt-get install openssh-server vim vino
```

vino needs to be enabled at boot or login:

```
mkdir -p ~/.config/autostart
cat <<EOF | tee ~/.config/autostart/vino-server.desktop 
[Desktop Entry]
Name=Desktop Sharing
Comment=GNOME Desktop Sharing Server
Exec=/usr/lib/vino/vino-server --sm-disable
Icon=preferences-desktop-remote-desktop
OnlyShowIn=GNOME;Unity;LXDE;
Terminal=false
Type=Application
AutostartCondition=GSettings org.gnome.Vino enabled
X-GNOME-Autostart-Phase=Applications
X-GNOME-AutoRestart=true
NoDisplay=true
X-Ubuntu-Gettext-Domain=vino
EOF
```
## Ubuntu stability settings

deactivate crash reporting:

    sudo sed -i 's/enabled=./enabled=0/' /etc/default/apport
    
deactivate update manager:

    sudo sed -i 's/X-GNOME-Autostart-Delay=60/X-GNOME-Autostart-enabled=false/' /etc/xdg/autostart/update-notifier.desktop

## Install

###  Firefox, git, imagetools  and curl

    sudo apt-get install firefox build-essential git-core curl imagemagick

### Ruby

best handled by Ruby Version Manager (https://rvm.io/rvm/install/)

    curl -L https://get.rvm.io | bash -s stable --ruby
    
close terminal and open new to activate rvm

#### install Ruby and dependencies

    rvm requirements

and install these.
On newer rvm this can be done automatically with

    rvm autolibs enable

then install and activate ruby, with bundler.

    rvm reinstall 1.9.3
    rvm use 1.9.3 --default
    gem install bundler
    
in Ubuntu, ~/.bash_profile is overridden if ~/.bashrc exists, so rvm config must be copied to ~./bashrc

```
cat <<EOF | tee -a ~/.bashrc
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
EOF
```

## App and RFID reader / BARCODE scanner

clone the repositories

    mkdir -p ~/code && cd ~/code
    git clone https://github.com/digibib/aktive-hyller
    cd aktive-hyller 
    git checkout develop && bundle

### RFID reader

    cd ~/code
    git clone https://github.com/digibib/rfidgeek.git
    cd rfidgeek 
    git checkout feature/sinatra-integration && bundle
    
needs access to dialout group

    sudo usermod -a -G dialout [username]

restart window manager (or machine)
    
    sudo service lightdm restart
    
#### RFID websocket integration


    cd ~/code/rfidgeek
 
copy configuration and adjust port to sinatra APP port. rfidgeek also comes with integrated websocket server for testing. this can be diabled in config

    cp config/config.yml-dist config/config.yml

### Settings

create settings file:

    cd ~/code/aktive-hyller
    cp config/settings.example.yml config/settings.yml
    
set ports and hostname for websocket if RFID reader. Activate websocket server for testing.

## Touchscreen

Will need a sensitive touch screen, though multitouch not needed, only

* click
* scroll

best handled by plugins in Firefox:

## Firefox
Aktive Hyller is tested and made to work with Firefox

### Firefox plugins
To hide tooltip and deactivate status messages:

* [Status-4-Evar]: https://addons.mozilla.org/en-US/firefox/addon/status-4-evar/

to handle scrolling and sensitivity:

* [Grab and drag]: http://grabanddrag.mozdev.org/installation.html
* make sure to disable "deactive dragging of linkes" under General tab (does exactly the opposite...)

to make sure fullscreen kicks in 
* [FF Fullscreen]: https://addons.mozilla.org/en-us/firefox/addon/FF_Fullscreen/

### other Firefox settings
in address window `about:config`

    nglayout.enable_drag_images            => false  (don't allow dragging images)
    browser.link.open_newwindow            => 1      (open new pages in active tab)
    browser.sessionstore.resume_from_crash => false (don't open annoying "Oops, something went wrong!)

## Setup and Configuration (Automatic)

for an Ubuntu/Debian installation, most settings below can be automatized by rake tasks. For a complete list of tasks:

    rake -T
    
Setup and configuration:

    rake setup:install
    rake setup:configure

settings for logo, background, RFID and/or Barcode scanner, etc. are all in config/settings.yml

to update configuration:

    rake configure
    
### Screen Saver

#### No Screen saver

If you only want start image you will only need to send a GET to /timeout and browser will reset itself

#### Video

Install video player:

```sudo apt-get install libav-tools```

you will need to activate xscreensaver and make a new play format in ~/.xscreensaver:
```
"Aktiv hylle screensaver" mplayer -x 1680 -y 1050 -wid $XSCREENSAVER_WINDOW -fs -loop 0 \
                          [/path/to/movie] >> /dev/null 2>&1 \n\
```

this one can now be selected in xscreensaver-demo

## Setup and Configuration (Manual)

### Automatic start script for firefox

need to make sure it respawns after crash

```
cat <<EOF | tee ~/code/aktivehyller.sh && chmod +x ~/code/aktivehyller.sh
#!/bin/bash
FIREFOX=/usr/bin/firefox
sleep 3
while true
do
  rm -rf ~/.mozilla/firefox/*.default/startupCache
  rm -rf ~/.mozilla/firefox/*.default/Cache
  firefox http://localhost:4567/timeout
  sleep 3s
done
EOF
```
### screensaver based browser reset

xscreensaver can be set to trigger events, and this is a good way to script timeout in firefox browser.
This script creates a loop that sends a GET to /timeout when screensaver kicks in and returns to start page:
(make sure to make about:config settings as described above to avoid multiple tabs to open)

```
cat <<EOF | tee ~/code/xscreensaver-timeout.sh && chmod +x ~/code/xscreensaver-timeout.sh
#!/bin/bash

process() {
while read input; do
  case "$input" in
    BLANK*)   (echo 'GET /timeout ';sleep 1) | telnet localhost 4567 && /usr/bin/firefox -remote "openurl(localhost:4567)" ;;
    UNBLANK*)	 echo "do nothing yet ..." ;;
    LOCK*)	   echo "lock .... do nothing yet" ;;
  esac
done
}

/usr/bin/xscreensaver-command -watch | process
EOF
```

### desktop items to automatic load startscripts on logon

```
cat <<EOF | tee ~/.config/autostart/aktivehyller.desktop
[Desktop Entry]
Encoding=UTF-8
Name=autologout
Comment=autologout
Exec=~/code/aktive-hyller/aktivehyller.sh
Type=Application
Categories=;
NotShowIn=GNOME;
NoDisplay=true
EOF
```

```
cat <<EOF | tee ~/.config/autostart/xscreensaver-timeout.desktop
[Desktop Entry]
Encoding=UTF-8
Name=xscreensaver-timeout
Comment=xscreensaver-timeout
Exec=~/code/aktive-hyller/xscreensaver-timeout.sh
Type=Application
Categories=;
NotShowIn=GNOME;
NoDisplay=true
EOF
```

#### automatisk start on boot

1. make a foreman Procfile

    gem install foreman

```
cat <<EOF | tee Procfile
app: /home/aktiv/.rvm/scripts/rvm; cd /home/aktiv/code/aktive-hyller; ruby app.rb
rfid: sleep 3; /home/aktiv/.rvm/scripts/rvm; cd /home/aktiv/code/rfidgeek; ruby rfid.rb
EOF
```

2. create upstart jobs

```rvmsudo foreman export upstart /etc/init -a aktivehyller -p 4567 -u aktiv -l ~/code/aktive-hyller/logs/upstart```

this creates an upstart job for both rfid reader and active shelf on port 4567 with logs on ~/code/aktive-hyller/logs/upstart
if to start automatically on booy add runlevel [2345]:

example upstart:

```
cat <<EOF | sudo tee /etc/init/aktivehyller.conf
pre-start script

bash << "EOF"
  mkdir -p /home/aktiv/code/aktive-hyller/logs/upstart
  chown -R aktiv /home/aktiv/code/aktive-hyller/logs/upstart
EOF

end script

start on (started network-interface
          or started network-manager
          or started networking
          and runlevel [2345]
          and local-filesystems)

stop on (stopping network-interface
         or stopping network-manager
         or stopping networking
         and runlevel [016])
EOF
```

## Aktive hyller configuration

* Rename `config/settings.example.yml' to 'settings.yml' and set variables
* Replace the file `public/img/logo.png` with your logo  (150x150px white on transparent background)
* If you have a leftbar image to replace with leftbar css, name it `public/img/leftbar.png` and set leftbar_image: true in settings.yml
* Run `rake configure`

### Generate and access statistics reports

Make sure sqlite3 is installed on your system:
```
sudo apt-get install sqlite3
```

Set up a cronjob to run `rake log:process` each night:

``` 
cat <<EOF | sudo tee /etc/cron.daily/aktive-hyller-daily && sudo chmod +x /etc/cron.daily/aktive-hyller-daily
#!/bin/bash
# daily log report
source /home/aktiv/.rvm/scripts/rvm
cd /home/aktiv/code/aktive-hyller
rake log:process >> logs/mail.log 2>&1
EOF
 ```

The statistics report will be accesible provided you know the IP-address of the station:
```
http://ip.address/stats/{daily|weekly|monthly}
```

In addition, you can set email adresses in `config/settings.yml` of those who wish to recieve the daily, weekly or monthly reports by email.

The `rake log:process` task will aslo send the daily email reports. You need to set up additional two cronjobs to send the weekly and monthly reports:

Weekly report
``` 
cat <<EOF | sudo tee /etc/cron.weekly/aktive-hyller-weekly && sudo chmod +x /etc/cron.weekly/aktive-hyller-weekly
#!/bin/bash
# weekly log report
source /home/aktiv/.rvm/scripts/rvm
cd /home/aktiv/code/aktive-hyller
rake email:weekly >> logs/mail.log 2>&1
EOF
```

Monthly report
```
cat <<EOF | sudo tee /etc/cron.monthly/aktive-hyller-monthly && sudo chmod +x /etc/cron.monthly/aktive-hyller-monthly
#!/bin/bash
# monthly log report
source /home/aktiv/.rvm/scripts/rvm
cd /home/aktiv/code/aktive-hyller
rake email:monthly >> logs/mail.log 2>&1
EOF
```

Mails are handlet by ssmtp which needs a dev account at Google API.
https://developers.google.com/google-apps/gmail/
the gmail dev sccount settings must be inserted into Settings file under 'gmail'


## Content

### Virtuoso install

    sudo apt-get install virtuoso-server virtuoso-vad-conductor

global config:

    /etc/default/virtuoso-opensource-6.1

database settings:
    /etc/virtuoso-opensource-6.1/virtuoso.ini

### Virtuoso through apache proxy

need mod_proxy:

    sudo apt-get install libapache2-mod-proxy-html

add virtualhost directive:

```
    <VirtualHost *:80>
    Alias /robots.txt /var/www/robots.txt
    Alias /favicon.ico /var/www/favicon.ico

    DocumentRoot /var/www/hostname
    ServerName hostname

    ProxyRequests Off
    ProxyPreserveHost on
    ProxyTimeout        300
    # Proxy ACL
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>

   <Proxy /sparql>
    Allow from all
    ProxyPass http://hostname:8890/sparql timeout=300
    ProxyPassReverse http://hostname:8890/sparql
   </Proxy>
   <Proxy /sparql-auth>
    Allow from all
    ProxyPass http://hostname:8890/sparql-auth timeout=300
    ProxyPassReverse http://hostname:8890/sparql-auth
   </Proxy>

    LimitRequestLine 1000000
    LimitRequestFieldSize 16380
</Virtualhost>
```

## MARC to RDF conversion

* [marc2rdf]: http://github.com/digibib/marc2rdf
