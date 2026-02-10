#!/bin/bash

set -e

USER_NAME="user"
HOME_DIR="/home/$USER_NAME"
URL_DEFAULT="http://192.168.203.86:8080"

echo "=== INSTALL KIOSK MODE ==="

apt update
apt install -y \
    xorg \
    xinit \
    openbox \
    chromium \
    unclutter \
    xdotool \
    wmctrl \
    fonts-dejavu-core \
    net-tools \
    curl

echo "=== URL file ==="
echo "$URL_DEFAULT" > $HOME_DIR/kiosk_url
chown $USER_NAME:$USER_NAME $HOME_DIR/kiosk_url

echo "=== Offline page ==="
mkdir -p $HOME_DIR/offline
cat > $HOME_DIR/offline/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Нет связи</title>
<style>
body {
  background:black;
  color:white;
  font-family:Arial;
  display:flex;
  justify-content:center;
  align-items:center;
  height:100vh;
  flex-direction:column;
}
button {
  font-size:28px;
  padding:20px 40px;
  margin-top:40px;
}
</style>
</head>
<body>
<h1>Нет связи с климатическим компьютером</h1>
<button onclick="location.reload()">Обновить</button>
</body>
</html>
EOF

chown -R $USER_NAME:$USER_NAME $HOME_DIR/offline

echo "=== .xinitrc ==="
cat > $HOME_DIR/.xinitrc <<'EOF'
#!/bin/bash

URL_FILE="/home/user/kiosk_url"
OFFLINE="/home/user/offline/index.html"

unclutter -idle 0 &
xset -dpms
xset s off
xset s noblank

while true; do

URL=$(cat $URL_FILE)

if curl --connect-timeout 2 -s "$URL" >/dev/null; then
    chromium \
      --kiosk "$URL" \
      --noerrdialogs \
      --disable-infobars \
      --disable-session-crashed-bubble \
      --no-first-run \
      --disable-translate \
      --disable-features=TranslateUI \
      --start-fullscreen
else
    chromium \
      --kiosk "file://$OFFLINE" \
      --noerrdialogs \
      --disable-infobars \
      --disable-session-crashed-bubble \
      --no-first-run \
      --start-fullscreen
fi

sleep 2
done
EOF

chmod +x $HOME_DIR/.xinitrc
chown $USER_NAME:$USER_NAME $HOME_DIR/.xinitrc

echo "=== autologin ==="
mkdir -p /etc/systemd/system/getty@tty1.service.d

cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

echo "startx" >> $HOME_DIR/.bash_profile
chown $USER_NAME:$USER_NAME $HOME_DIR/.bash_profile

echo "=== kiosk-set-url ==="
cat > /usr/local/bin/kiosk-set-url <<'EOF'
#!/bin/bash

URL="$1"

if [ -z "$URL" ]; then
  echo "Использование: kiosk-set-url http://IP:PORT"
  exit 1
fi

echo "$URL" > /home/user/kiosk_url
echo "URL изменён на $URL"

pkill X
EOF

chmod +x /usr/local/bin/kiosk-set-url

echo
echo "=== ГОТОВО ==="
echo
echo "Перезагрузи систему:"
echo "reboot"
echo
echo "Смена адреса:"
echo "kiosk-set-url http://IP:PORT"
echo
