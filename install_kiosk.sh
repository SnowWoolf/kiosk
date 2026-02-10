#!/bin/bash
set -e

USER_NAME=$(logname)
HOME_DIR="/home/$USER_NAME"

SERVER_IP="192.168.203.8"
URL="http://192.168.203.8"

echo "install packages"
apt update
apt install -y chromium unclutter wmctrl xdotool

echo "disable sleep"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

echo "create kiosk page"
mkdir -p /opt/kiosk

cat >/opt/kiosk/offline.html <<EOF
<html>
<head>
<meta charset="utf-8">
<style>
body{
 background:black;
 color:white;
 font-family:Arial;
 display:flex;
 align-items:center;
 justify-content:center;
 height:100vh;
 flex-direction:column;
}
button{
 font-size:30px;
 padding:20px 40px;
}
</style>
</head>
<body>
<h1>Нет связи с климатическим компьютером</h1>
<button onclick="location.reload()">Обновить страницу</button>
</body>
</html>
EOF

echo "kiosk launcher"

cat >/usr/local/bin/kiosk.sh <<EOF
#!/bin/bash

export DISPLAY=:0

unclutter -idle 0 -root &

while true
do
 if ping -c1 -W1 $SERVER_IP >/dev/null
 then
   chromium \
     --kiosk \
     --start-fullscreen \
     --noerrdialogs \
     --disable-infobars \
     --disable-session-crashed-bubble \
     --disable-translate \
     $URL
 else
   chromium \
     --kiosk \
     --app=file:///opt/kiosk/offline.html
 fi

 sleep 2
done
EOF

chmod +x /usr/local/bin/kiosk.sh

echo "systemd service"

cat >/etc/systemd/system/kiosk.service <<EOF
[Unit]
Description=Kiosk
After=graphical.target

[Service]
User=$USER_NAME
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/kiosk.sh
Restart=always

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable kiosk.service

echo "autologin xfce"

mkdir -p /etc/lightdm/lightdm.conf.d

cat >/etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=$USER_NAME
autologin-session=xfce
EOF

echo "DONE"
echo "REBOOT NOW"
