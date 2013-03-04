# Aktive hyller Setup and Configuration

## Linux install for Aktive Hyller
Install lubuntu 12.04 LTS or newer

update and install necessary packages:

### Remote management

```bash
sudo update && sudo upgrade
sudo apt-get install openssh-server vim xnest
```

### Firefox, git and curl

    sudo apt-get install firefox
    sudo apt-get install build-essential git-core curl

### Ruby

best handled by Ruby Version Manager (https://rvm.io/rvm/install/)

    curl -L https://get.rvm.io | bash -s stable --ruby

#### find your system's dependencies:

    rvm requirements

and install these.

then install ruby.

    rvm reinstall 1.9.3

## App and RFID reader

clone the repositories

    mkdir -p code && cd code
    git clone https://github.com/digibib/aktive-hyller
    git clone https://github.com/digibib/rfidgeek.git

### RFID reader

needs access to dialout group

    sudo usermod -a -G dialout [username]

restart window manager

#### RFID websocket client

    git checkout feature/sinatra-integration

    cp config/config.yml-dist config/config.yml

set ports and

## Virtuoso install

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

More to come...

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

### other Firefox settings
in address window `about:config`

    nglayout.enable_drag_images til false

### Automatic start script for firefox

need to make sure it respawns after crash

```
cat <<EOF | tee ~/code/aktivehyller.sh && chmod +x ~/code/aktivehyller.sh
#!/bin/bash
FIREFOX=/usr/bin/firefox
sleep 3
while true
  rm -rf ~/.mozilla/firefox/*.default/startupCache
  rm -rf ~/.mozilla/firefox/*.default/Cache
  firefox -private http://localhost:4567/timeout
  sleep 3s
end
EOF
```
### screensaver based browser reset

xscreensaver can be set to trigger events, and this is a good way to script timeout in firefox browser:

```
cat <<EOF | tee ~/code/xscreensaver-timeout.sh && chmod +x ~/code/xscreensaver-timeout.sh
#!/bin/bash

process() {
while read input; do
  case "$input" in
    BLANK*)   (echo 'GET /timeout ';sleep 1) | telnet localhost 4567  ;;
    UNBLANK*)	 echo "start something? " ;;
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
Exec=/home/aktiv/code/aktive-hyller/aktivehyller.sh
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
Name=autologout
Comment=autologout
Exec=/home/aktiv/code/aktive-hyller/xscreensaver-timeout.sh
Type=Application
Categories=;
NotShowIn=GNOME;
NoDisplay=true
EOF
```

### remote access ###

openssh, as described above

### remote desktop

settings in /etc/lightdm/lightdm.conf:

```
[SeatDefaults]
xserver-allow-tcp=true #  TCP/IP connections are allowed to this X server
# xdmcp-port = XDMCP UDP/IP port to communicate on
# xdmcp-key = Authentication key to use for XDM-AUTHENTICATION-1 (stored in keys.conf)
session-setup-script = su - aktiv -c aktivehyller.sh # Script to run when starting a user session (runs as root)
autologin-user=aktiv

[XDMCPServer]
enabled=true
```

'xnest' allows for testing on external desktop
1. connect with x forwarding
    ssh -X user@iptoserver
2. start session on local computer
    Xnest :1 -ac -geometry 800x480 -once -query localhost

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

``` TODO ```

The statistics report will be accesible provided you know the IP-address of the station:
```
http://ip.address/stats/{day|week|month}
```

In addition, you can set email adresses in `config/settings.yml` of those who wish to recieve the daily, weekly or monthly reports by email.

The `rake log:process` task will aslo send the daily email reports. You need to set up additional two cronjobs to send the weekly and monthly reports:

``` TODO rake email:weekly```

``` TODO rake email:monthly```

## Configure sendmail
The applications relies on the Linux mail agent `sendmail` to deliver emails:

```sudo apt-get install sendmail```

Be sure to set a valid hostname. Check `/var/log/mail.log` to ensure that the mails are sendt. Theese mails are likely to be treated as spam, so recipients should check their spam-folders if it doesn't arrive.

## Screen Saver

you will need to activate xscreensaver and make a new play format in ~/.xscreensaver:
```
"Aktiv hylle screensaver" mplayer -x 1680 -y 1050 -wid $XSCREENSAVER_WINDOW -fs -loop 0 \
                          [/path/to/movie] >> /dev/null 2>&1 \n\
```

this one can now be selected in xscreensaver-demo
