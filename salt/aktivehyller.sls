########## 
# PACKAGES
##########

removepkgs:
  pkg.purged:
    - pkgs:
      - firefox-locale-en
      - chromium-browser
      - abiword
      - sylpheed
      - apport
      - pidgin
      - transmission
      - gnumeric
      - xfburn
      - mtpaint
      - simple-scan

installpkgs:
  pkg.latest:
    - pkgs:
      - firefox
      - firefox-locale-nb
      - git-core
      - build-essential
      - curl
      - imagemagick
      - ruby1.9.1-dev
      - screen
      - vino
      - libav-tools
      - sqlite3
      - libsqlite3-dev
      - openssh-server

bundler: 
  pkg:
    - installed
    - require:
      - pkg: installpkgs

######## 
# USERS
########

aktivuser:
  user.present:
    - name: aktiv
    - fullname: Aktivehyller
    - shell: /bin/bash
    - home: /home/aktiv
    - groups:
      - dialout
      - adm
      - staff
      - users
      - plugdev
      - aktiv
      - sudo
    
######## 
# GIT
########
                  
https://github.com/digibib/aktive-hyller.git:
  git.latest:
  - rev: master
  - target: /home/aktiv/code/aktive-hyller
  - user: aktiv
  - force: True
  - require:
    - user: aktiv

https://github.com/digibib/rfidgeek.git:
  git.latest:
  - rev: feature/sinatra-integration
  - target: /home/aktiv/code/rfidgeek
  - user: aktiv
  - force: True
  - require:
    - user: aktiv

########## 
# RUBYGEMS
##########

bundle_rfid:
  cmd.run:
    - name: bundle > bundle.txt
    - cwd: /home/aktiv/code/rfidgeek
    - stateful: True
    - require:
      - pkg: bundler
      - git: https://github.com/digibib/rfidgeek.git
        
bundle_ah:
  cmd.run:
    - name: bundle > bundle.txt
    - cwd: /home/aktiv/code/aktive-hyller
    - stateful: True
    - require:
      - pkg: bundler
      - git: https://github.com/digibib/aktive-hyller.git

      
######## 
# GLOBAL SETTINGS
########

#/etc/upstart-xsessions:
#  file.append:
#    - text: Lubuntu
#    - stateful: True

/etc/init/aktivehyller.conf:
  file.managed:
    - source: salt://aktivehyller/files/aktivehyller.conf
    - stateful: True

/etc/init/rfidgeek.conf:
  file.managed:
    - source: salt://aktivehyller/files/rfidgeek.conf
    - stateful: True
        
######## 
# LOCAL SETTINGS
########
    
/home/aktiv/code/aktive-hyller/config/settings.yml:
  file.managed:
    - source: salt://aktivehyller/files/ahsettings.yml
    - user: aktiv
    - group: aktiv

/home/aktiv/code/rfidgeek/config/config.yml:
  file.managed:
    - source: salt://aktivehyller/files/rfidconfig.yml
    - user: aktiv
    - group: aktiv
    
/home/aktiv/code/aktive-hyller/public/img/startscreen.png:
  file.managed:
    - source: salt://aktivehyller/files/startscreen.png
    - user: aktiv
    - group: aktiv

/home/aktiv/code/aktive-hyller/public/img/leftbar.png:
  file.managed:
    - source: salt://aktivehyller/files/leftbar.png
    - user: aktiv
    - group: aktiv
              
/home/aktiv/code:
  file.directory:
    - user: aktiv
    - group: aktiv
    - makedirs: True
    - recurse:
      - user
      - group

/home/aktiv/.config/autostart:
  file.directory:
    - user: aktiv
    - group: aktiv
    - makedirs: True

/home/aktiv/.config/autostart/aktivehyller.desktop:
  file.symlink:
    - target: /home/aktiv/code/aktive-hyller/scripts/aktivehyller.desktop
    - user: aktiv
    - group: aktiv

/home/aktiv/.config/autostart/xscreensaver-timeout.desktop:
  file.symlink:
    - target: /home/aktiv/code/aktive-hyller/scripts/xscreensaver-timeout.desktop
    - user: aktiv
    - group: aktiv
    
########## 
# SERVICES
##########

aktivehyller:
  service:
    - running
    - enable: True
    - require:
      - cmd: bundle_ah
      - file: /etc/init/aktivehyller.conf
      - file: /home/aktiv/code/aktive-hyller/config/settings.yml
    - watch:
      - file: /home/aktiv/code/aktive-hyller/config/settings.yml

rfidgeek:
  service:
    - running
    - enable: True
    - require:
      - service: aktivehyller
      - file: /etc/init/rfidgeek.conf
    - watch:
      - file: /home/aktiv/code/rfidgeek/config/config.yml

lightdm:
  service:
    - running
    - watch:
      - git: https://github.com/digibib/aktive-hyller.git
      - git: https://github.com/digibib/rfidgeek.git
    - cmd.run:
      - name: pkill xscreensaver-timeout.sh
    - cmd.run:
      - name: pkill aktivehyller.sh

