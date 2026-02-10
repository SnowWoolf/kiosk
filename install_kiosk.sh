apt update
apt install -y xorg xinit openbox chromium unclutter wmctrl xdotool fonts-dejavu-core curl

useradd -m kiosk
passwd -d kiosk

mkdir -p /home/kiosk/.config/openbox
mkdir -p /opt/kiosk

# ---------- URL ----------
echo "http://192.168.203.86:8080" > /opt/kiosk/url

# ---------- Страница нет связи ----------
cat > /opt/kiosk/offline.html <<'EOF'
<html>
<head>
<meta charset="utf-8">
<style>
body{
background:#111;
color:#fff;
font-family:Arial;
display:flex;
align-items:center;
justify-content:center;
height:100vh;
flex-direction:column;
}
button{
font-size:32px;
padding:20px 40px;
margin-top:40px;
}
</style>
</head>
<body>
<h1>Нет связи с климатическим компьютером</h1>
<button onclick="location.reload()">Обновить страницу</button>
</body>
</html>
EOF

# ---------- kiosk script ----------
cat > /opt/kiosk/kiosk.sh <<'EOF'
#!/bin/bash

xset -dpms
xset s off
xset s noblank

unclutter -idle 0.1 -root &

while true
do
URL=$(cat /opt/kiosk/url)

if curl -m 2 -I "$URL" >/dev/null 2>&1
then
    chromium \
    --kiosk "$URL" \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-translate \
    --disable-features=TranslateUI \
    --overscroll-history-navigation=0 \
    --check-for-update-interval=31536000
else
    chromium --kiosk file:///opt/kiosk/offline.html
fi

sleep 2
done
EOF

chmod +x /opt/kiosk/kiosk.sh

# ---------- openbox autostart ----------
cat > /home/kiosk/.config/openbox/autostart <<'EOF'
/opt/kiosk/kiosk.sh &
EOF

chown -R kiosk:kiosk /home/kiosk

# ---------- startx on login ----------
cat >> /home/kiosk/.bash_profile <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
startx
fi
EOF

# ---------- xinit ----------
cat > /home/kiosk/.xinitrc <<'EOF'
exec openbox-session
EOF

chown kiosk:kiosk /home/kiosk/.bash_profile
chown kiosk:kiosk /home/kiosk/.xinitrc

# ---------- autologin tty ----------
mkdir -p /etc/systemd/system/getty@tty1.service.d

cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I $TERM
EOF

# ---------- команда смены URL ----------
cat > /usr/local/bin/kiosk-set-url <<'EOF'
#!/bin/bash
echo "$1" > /opt/kiosk/url
reboot
EOF

chmod +x /usr/local/bin/kiosk-set-url

echo "===== ГОТОВО ====="
echo "Перезагрузи систему"
