# Raspberry Pi - Headless Spotifyd Client with Bluetooth

## Status 
This is currently working as-is, it boots and automatically presents in the official spotify app and automatically pairs to the bluetooth speaker successfully, but after some time it stops working or becomes inconsistent. I think the best solution is to eliminate the bluetooth complexity with a wired (amplified) speaker(s).

## Installation Notes

* Raspberry Pi 3B+
* Ubuntu 24.04 LTS
* https://docs.spotifyd.rs/installation/index.html

This is incomplete but covers most of the commands used in inital config.

```
sudo apt update
sudo apt install spotifyd
sudo apt install pi-bluetooth
sudo apt install bluetooth

wget https://github.com/Spotifyd/spotifyd/releases/download/v0.4.1/spotifyd-linux-aarch64-slim.tar.gz
tar xzf spotifyd-*.tar.gz # extract
chmod +x ./spotifyd
sudo mv spotifyd /usr/local/bin/
sudo chown root:root /usr/local/bin/spotifyd
spotifyd --version
sudo apt install libasound2t64
sudo mv spotifyd.service /etc/systemd/system/
sudo systemctl enable spotifyd.service --now
sudo mv autopair /usr/local/bin/
sudo chmod +x /usr/local/bin/autopair
sudo chown root:root /usr/local/bin/autopair
```

`crontab -e` and add `@reboot sleep 10 && /usr/local/bin/autopair`

```
aplay -L
spotifyd --no-daemon --device bluealsa
amixer sset bluealsa 50%
bluetoothctl pair 04:52:C7:57:65:1E
bluetoothctl connect 04:52:C7:57:65:1E
bluetoothctl trust 04:52:C7:57:65:1E
```

