#!/bin/bash
set -e

KIOSK_URL="[http://192.168.202.206:5173/](http://192.168.202.206:5173/)"

apt-get update
apt-get install -y 
xorg 
openbox 
lightdm 
chromium 
unclutter 
xdotool 
curl 
openssh-server

systemctl enable ssh

# user

id kiosk &>/dev/null || useradd -m -s /bin/bash kiosk
mkdir -p /home/kiosk/.config/openbox
chown -R kiosk:kiosk /home/kiosk

# конфиг URL

cat > /etc/kiosk.conf <<EOF
KIOSK_URL="$KIOSK_URL"
EOF

# lightdm автологин

cat > /etc/lightdm/lightdm.conf <<EOF
[Seat:*]
autologin-user=kiosk
autologin-session=openbox
xserver-command=X -nocursor -nolisten tcp
EOF

# openbox autostart

cat > /home/kiosk/.config/openbox/autostart <<'EOF'
#!/bin/bash

setxkbmap -option terminate:ctrl_alt_bksp

unclutter -idle 0 -root &

# запуск watchdog

systemctl --user start kiosk-watchdog.service
EOF

chown kiosk:kiosk /home/kiosk/.config/openbox/autostart
chmod +x /home/kiosk/.config/openbox/autostart

# systemd user service

mkdir -p /home/kiosk/.config/systemd/user

cat > /home/kiosk/.config/systemd/user/kiosk-watchdog.service <<'EOF'
[Unit]
Description=Kiosk Watchdog
After=graphical-session.target

[Service]
ExecStart=/usr/local/bin/kiosk-watchdog.sh
Restart=always

[Install]
WantedBy=default.target
EOF

chown -R kiosk:kiosk /home/kiosk/.config/systemd

# watchdog script

cat > /usr/local/bin/kiosk-watchdog.sh <<'EOF'
#!/bin/bash

source /etc/kiosk.conf

while true
do

# ждём сервер

until curl -s --max-time 2 "$KIOSK_URL" > /dev/null; do
echo "Server offline, waiting..."
sleep 5
done

echo "Server online, starting chromium"

chromium 
--kiosk "$KIOSK_URL" 
--noerrdialogs 
--disable-infobars 
--disable-session-crashed-bubble 
--disable-translate 
--start-maximized

echo "Chromium crashed, restarting..."
sleep 3
done
EOF

chmod +x /usr/local/bin/kiosk-watchdog.sh

# команда смены IP

cat > /usr/local/bin/kiosk-set-url <<'EOF'
#!/bin/bash
if [ -z "$1" ]; then
echo "usage: kiosk-set-url [http://IP:PORT/](http://IP:PORT/)"
exit 1
fi

sudo sed -i "s|KIOSK_URL=.*|KIOSK_URL="$1"|" /etc/kiosk.conf
echo "URL changed to $1"
sudo systemctl restart lightdm
EOF

chmod +x /usr/local/bin/kiosk-set-url

echo "INSTALL DONE"
echo "Reboot system"
