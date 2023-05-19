# install monitoring tools:
sudo apt-get install plocate pgtop htop iftop nethogs iotop sysstat net-tools

# test and enable sar
# test and enable sar
sudo apt-get install sysstat
grep -i -e ENABLED /etc/default/sysstat 
sudo sed -i 's/ENABLED="false"/ENABLED="true"/g' /etc/default/sysstat; 
sudo systemctl enable sysstat.service
sudo systemctl restart sysstat.service
# modify collection schedule:
sudo vim /etc/cron.d/sysstat
# check all sysstats files;
find /etc -iname sysstat*
# update timers:
sudo vim /etc/systemd/system/sysstat.service.wants/sysstat-collect.timer
sudo vim /etc/systemd/system/sysstat.service.wants/sysstat-summary.timer
sudo systemctl restart sysstat.service

# change the timer collection times - override default configuration:
sudo systemctl edit sysstat-collect.timer
sudo systemctl restart sysstat-collect.timer
sudo systemctl status sysstat-collect.timer
