# Oppsett av Virtuoso og konvertering av MARC til RDF

## Virtuoso installering

    sudo apt-get install virtuoso-server virtuoso-vad-conductor

global config: 
    /etc/default/virtuoso-opensource-6.1
database settings:
    /etc/virtuoso-opensource-6.1/virtuoso.ini

### Virtuoso through apache proxy

need mod_proxy:
    sudo apt-get install libapache2-mod-proxy-html

add virtualhost directive:

```<VirtualHost *:80>
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
</Virtualhost>```

## MARC to RDF conversion

Mer info kommer...

## Klargjøring og oppsett av linux til å kjøre Aktive Hyller
Installer lubuntu 12.04 LTS eller nyere, f.eks. fra live-CD

oppdater og installer påkrevde pakker:

```sudo update && sudo upgrade
sudo apt-get install xserver-xorg-input-multitouch
sudo apt-get install openssh-server vim xnest```

## Touch-skjerm

Multitouch er vel og bra men applikasjonen trenger bare to funksjoner:
* klikk
* scroll

dette håndteres best som plugin i Firefox:

## Firefox
Aktive Hyller er laget og testet for Firefox.

### Firefox plugins
For å skjule URL tooltip som dukker opp i nedre venstre hjørne ved hver sidelasting, kan man installere programtillegget [Status-4-Evar] og deaktivere alle statusmeldinger (Vis nettverksstatus, vis standardstatus osv)

[Reset Kiosk] pluginet gjør det mulig å angi at nettleseren skal resetes (dvs gå tilbake til aktive hyller startsiden) etter x antall minutter med inaktivitet.

[Reset Kiosk]: https://addons.mozilla.org/en-US/firefox/addon/reset-kiosk/
[Status-4-Evar]: https://addons.mozilla.org/en-US/firefox/addon/status-4-evar/

[Grab and drag]: http://grabanddrag.mozdev.org/installation.html
kan håndtere scrolling, og kan sette sensitivitet og funksjon, f.eks. deaktivere 'drag link' osv.

### Firefox settings
Sett følgende instillinger ved å skrive `about:config` i adressefeltet til Firefox:

```nglayout.enable_drag_images til false```

### Automatisk oppstartskript for firefox

cat <<EOF | tee ~/code/aktivehyller.sh && chmod +x ~/code/aktivehyller.sh
#!/bin/bash
sleep 3
rm -rf ~/.mozilla/firefox/*.default/startupCache
rm -rf ~/.mozilla/firefox/*.default/Cache
firefox -private http://localhost:4567
EOF

### lag en autostart-fil for automatisk å starte denne ved oppstart

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

### fjerntilgang ###

fjerntilgang via ssh er det beste for å gjøre vedlikehold, oppgradering, etc, oppenssh-server ble installert ovenfor

### remote desktop

innstillinger i /etc/lightdm/lightdm.conf:

```[SeatDefaults]
xserver-allow-tcp=true #  TCP/IP connections are allowed to this X server
# xdmcp-port = XDMCP UDP/IP port to communicate on
# xdmcp-key = Authentication key to use for XDM-AUTHENTICATION-1 (stored in keys.conf)
session-setup-script = su - aktiv -c aktivehyller.sh # Script to run when starting a user session (runs as root)
autologin-user=aktiv

[XDMCPServer]
enabled=true```

'xnest' gir mulighet til å bruke ekstern desktop hvis du vil teste
1. koble til stasjon med x forwarding
    ssh -X user@iptoserver
2. start en vindussesjon på egen maskin
    Xnest :1 -ac -geometry 800x480 -once -query localhost

du kan nå teste applikasjonen lokalt

#### automatisk oppstart

1. lag en foreman Procfile, kan ikke begynne med cd pga. en bug i foreman...:

```cat <<EOF | tee Procfile
app:  sleep 0; cd /home/aktiv/code/aktive-hyller; ruby app.rb
rfid:  sleep 3; cd /home/aktiv/code/rfidgeek; ruby rfid.rb
EOF
```
2. lag upstart oppstartsjobber:
    rvmsudo foreman export upstart /etc/init -a aktivehyller -p 4567 -u aktiv -l ~/code/aktive-hyller/logs/upstart

her lager vi en oppstartsjobb for både rfidleser og aktive-hyller, som kjører med bruker aktiv på port 4567 og logger til ~/code/aktive-hyller/logs/upstart
hvis applikasjonen skal starte fra boot må det legges til runlevel [2345]:

eksempel på upstart-fil:

```cat <<EOF | sudo tee /etc/init/aktivehyller.conf
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
EOF```
