ssh $1 "cd /home/aktiv/code/aktive-hyller; git pull; source /home/aktiv/.bashrc; source /home/aktiv/.bash_profile; bundle; pkill firefox; sudo service aktivehyller restart"