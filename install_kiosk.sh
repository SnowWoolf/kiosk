#!/bin/bash
set -e

USER_NAME=${SUDO_USER:-user}
HOME_DIR="/home/$USER_NAME"
URL_DEFAULT="http://192.168.203.8"

echo "INSTALL"
apt update
apt install -y chromium xdotool wmctrl

echo "DISABLE KEYRING"
apt purge -y gnome-keyring seahorse || true
rm -rf $HOME_DIR/.local/share/keyrings

echo "DISABLE SLEEP"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

echo "HIDE CURSOR HARD"
mkdir -p /etc/X11/xorg.conf.d
cat >/etc/X11/xorg.conf.d/99-hide-cursor.conf <<EOF
Section "Device"
 Identifier "dummy"
 Option "HWCursor" "off"
EndSection
EOF

echo "OFFLINE PAGE"
cat >/opt/kiosk_offline.html <<EOF
<html>
<head>
<meta charset="utf-8">
<style>
body{background:#111;color:white;font-family:Arial;
display:flex;align-items:center;justify-content:center;
height:100vh;flex-direction:column}
button{font-size:28px;padding:20px 40px;margin-top:40px}
</style>
</head>
<body>
<h1>Нет связи с климатическим компьютером</h1>
<button onclick="location.reload()">Обновить страницу</button>
</body>
</html>
EOF

echo "KIOSK SCRIPT"

cat >/usr/local/bin/kiosk.sh <<'EOF'
#!/bin/bash

URL_FILE="/etc/kiosk_url"
DEFAULT_URL="http://192.168.203.8"
[ -f "$URL_FILE" ] && URL=$(cat $URL_FILE) || URL=$DEFAULT_URL

HOST=$(echo $URL | cut -d/ -f3 | cut -d: -f1)

xset s off
xset -dpms
xset s noblank
xsetroot -cursor_name none

sleep 2

start_browser(){
 pkill chromium || true
 chromium \
  --kiosk \
  --app="$URL" \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=TranslateUI &
}

show_offline(){
 pkill chromium || true
 chromium \
  --kiosk \
  --app=file:///opt/kiosk_offline.html &
}

start_browser

while true
do
 if ping -c1 -W1 "$HOST" >/dev/null
 then
   if ! pgrep -f "$URL" >/dev/null; then
      start_browser
   fi
 else
   if ! pgrep -f kiosk_offline >/dev/null; then
      show_offline
   fi
 fi

 sleep 3
done
EOF

chmod +x /usr/local/bin/kiosk.sh

echo "AUTOSTART XFCE"

mkdir -p $HOME_DIR/.config/autostart
cat >$HOME_DIR/.config/autostart/kiosk.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/kiosk.sh
X-GNOME-Autostart-enabled=true
Name=Kiosk
EOF

chown -R $USER_NAME:$USER_NAME $HOME_DIR/.config

echo "URL COMMAND"
cat >/usr/local/bin/kiosk-set-url <<'EOF'
#!/bin/bash
echo "$1" | sudo tee /etc/kiosk_url
EOF
chmod +x /usr/local/bin/kiosk-set-url

echo "DONE"
echo "REBOOT"
/sbin/reboot
