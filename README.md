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

to reset browser after inactivity

* [Reset Kiosk]: https://addons.mozilla.org/en-US/firefox/addon/reset-kiosk/

to handle scrolling and sensitivity:

* [Grab and drag]: http://grabanddrag.mozdev.org/installation.html

### other Firefox settings
in address window `about:config` 

    nglayout.enable_drag_images til false

### Automatic start script for firefox

```
cat <<EOF | tee ~/code/aktivehyller.sh && chmod +x ~/code/aktivehyller.sh
#!/bin/bash
sleep 3
rm -rf ~/.mozilla/firefox/*.default/startupCache
rm -rf ~/.mozilla/firefox/*.default/Cache
firefox -private http://localhost:4567
EOF
```

### desktop item to automatic load startscript on logon

```
cat <<EOF | tee ~/.config/autostart/aktivehyller.desktop
[Desktop Entry]
Encoding=UTF-8
Name=autologout
Comment=autologout
Exec=/home/aktiv/code/aktivehyller.sh
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
