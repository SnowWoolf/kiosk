#!/bin/bash
set -e

SERVER_IP="192.168.203.8"
URL="http://192.168.203.8"

echo "Installing kiosk..."

apt update
apt install -y \
    chromium \
    unclutter \
    xdotool \
    wmctrl \
    x11-xserver-utils

########################################
# автологин user
########################################
mkdir -p /etc/systemd/system/getty@tty1.service.d

cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin user --noclear %I \$TERM
EOF

########################################
# XFCE автозапуск
########################################
mkdir -p /home/user/.config/autostart

cat >/home/user/.config/autostart/kiosk.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Kiosk
Exec=/usr/local/bin/kiosk.sh
EOF

chown -R user:user /home/user/.config

########################################
# скрыть курсор
########################################
mkdir -p /etc/X11/xorg.conf.d

cat >/etc/X11/xorg.conf.d/90-hide-cursor.conf <<EOF
Section "InputClass"
    Identifier "HideCursor"
    MatchIsPointer "on"
    Option "HWCursor" "off"
EndSection
EOF

########################################
# kiosk.sh
########################################
cat >/usr/local/bin/kiosk.sh <<EOF
#!/bin/bash

SERVER="$SERVER_IP"
URL="$URL"

xset s off
xset -dpms
xset s noblank

unclutter -idle 0 -root &

sleep 3

MON=\$(xrandr | grep " connected" | head -n1 | cut -d" " -f1)
MODE=\$(xrandr | grep "*" | head -n1 | awk '{print \$1}')

xrandr --output "\$MON" --mode "\$MODE"

while true; do

    if ping -c1 -W1 \$SERVER >/dev/null; then
        PAGE="\$URL"
    else
        PAGE='data:text/html,<html style="background:black;color:white;font-size:40px;display:flex;align-items:center;justify-content:center;height:100%;flex-direction:column">Нет связи с климатическим компьютером<br><br><button style="font-size:40px" onclick="location.reload()">Обновить страницу</button></html>'
    fi

    chromium \
      --kiosk \
      --start-fullscreen \
      --incognito \
      --noerrdialogs \
      --disable-infobars \
      --disable-session-crashed-bubble \
      --overscroll-history-navigation=0 \
      --check-for-update-interval=31536000 \
      "\$PAGE"

    sleep 2
done
EOF

chmod +x /usr/local/bin/kiosk.sh

echo "DONE. Rebooting..."
sleep 2
reboot
