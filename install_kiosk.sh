#!/bin/bash
set -e

SERVER_IP="192.168.203.8"
URL="http://192.168.203.8"
USER_NAME="user"

echo "=== INSTALL KIOSK MODE ==="

apt update
apt install -y \
xorg xinit openbox \
chromium \
unclutter wmctrl xdotool \
fonts-dejavu-core \
locales

echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

### kiosk script
cat >/usr/local/bin/kiosk.sh <<EOF
#!/bin/bash
export LANG=ru_RU.UTF-8
export DISPLAY=:0

xset -dpms
xset s off
xset s noblank
unclutter -idle 0 -root &

show_no_link() {
if ! wmctrl -l | grep -q NO_LINK; then
xmessage -center -title NO_LINK -geometry 600x200 \
-fn "-misc-dejavu sans-bold-r-normal--22-*-*-*-*-*-*-*" \
"Нет связи с климатическим компьютером

Нажмите «Обновить страницу»" \
-buttons "Обновить:0" &
fi
}

hide_no_link() {
wmctrl -l | grep NO_LINK | awk '{print \$1}' | xargs -r wmctrl -ic
}

chromium \
--kiosk \
--noerrdialogs \
--disable-infobars \
--disable-session-crashed-bubble \
--overscroll-history-navigation=0 \
--check-for-update-interval=31536000 \
"$URL" &

sleep 5
wmctrl -r Chromium -b add,fullscreen

while true; do
if ping -c1 -W1 $SERVER_IP >/dev/null; then
hide_no_link
xdotool key F5
else
show_no_link
fi
sleep 5
done
EOF

chmod +x /usr/local/bin/kiosk.sh

### .xinitrc
cat >/home/$USER_NAME/.xinitrc <<EOF
#!/bin/bash
exec /usr/local/bin/kiosk.sh
EOF

chmod +x /home/$USER_NAME/.xinitrc
chown $USER_NAME:$USER_NAME /home/$USER_NAME/.xinitrc

### автологин tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d

cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

### автозапуск X
cat >/home/$USER_NAME/.bash_profile <<EOF
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
startx
fi
EOF

chown $USER_NAME:$USER_NAME /home/$USER_NAME/.bash_profile

echo "=== DONE ==="
echo "Rebooting..."

sleep 3
/sbin/reboot
