#!/bin/sh
# setup-pi.sh — deploy the fully automated catalog publisher to the Pi 5.
# Run from your MacBook. Re-runnable. The Pi does everything nightly at
# 03:10: upstream re-scan -> versions -> cache -> generate -> Ed25519-SIGN
# -> push. The key exists only on the Pi + the offline Desktop copy.
set -eu
PI=loki@192.168.178.91
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "0/6 one-time system packages (sudo on the Pi)"
ssh -t "$PI" 'sudo apt-get install -y -qq git binutils libc6-dev libcurl4-openssl-dev libedit2 libsqlite3-0 libxml2 libz3-4 zlib1g-dev pkg-config tzdata'

echo "1/6 wait for the Swift toolchain (background download)"
ssh "$PI" 'until [ -f ~/toolchain/.ready ]; do sleep 5; done; ls -d ~/toolchain/swift-*'

echo "2/6 build pkgindex on the Pi (one-time, ~10-20 min)"
ssh "$PI" 'export PATH=$(ls -d ~/toolchain/swift-*/usr/bin):$PATH
  cd ~/amipkg-src/AmigaBuildKit && swift build -c release --product pkgindex
  cp .build/release/pkgindex ~/amipkg-publisher/pkgindex
  ~/amipkg-publisher/pkgindex 2>&1 | head -1'

echo "3/6 SIGNING KEY (the deliberate step)"
scp -q "$HOME/Desktop/amiga-imager-repo/SIGNING-KEY-KEEP-OFFLINE.txt" "$PI:~/amipkg-publisher/signing-key.txt"
ssh "$PI" 'chmod 600 ~/amipkg-publisher/signing-key.txt'

echo "4/6 deploy key + repo clone"
ssh "$PI" 'test -f ~/.ssh/amipkg_deploy || ssh-keygen -t ed25519 -N "" -C amipkg-nightly@pi -f ~/.ssh/amipkg_deploy -q
  grep -q "Host amiga-pkg-github" ~/.ssh/config 2>/dev/null || printf "\nHost amiga-pkg-github\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/amipkg_deploy\n  IdentitiesOnly yes\n" >> ~/.ssh/config
  cat ~/.ssh/amipkg_deploy.pub' > /tmp/amipkg_deploy.pub
gh repo deploy-key add /tmp/amipkg_deploy.pub --repo thomas-luebker/amiga-pkg --title "pi nightly publisher" --allow-write 2>/dev/null || echo "  (deploy key already registered)"
ssh "$PI" 'test -d ~/amipkg-publisher/amiga-pkg || git clone -q https://github.com/thomas-luebker/amiga-pkg.git ~/amipkg-publisher/amiga-pkg
  cd ~/amipkg-publisher/amiga-pkg && git remote set-url --push origin amiga-pkg-github:thomas-luebker/amiga-pkg.git
  git config user.name "amipkg-nightly" && git config user.email "amipkg@amiga-imager.com"'

echo "5/6 install script + systemd timer"
scp -q "$HERE/nightly-publish.sh" "$PI:~/amipkg-publisher/nightly-publish.sh"
ssh "$PI" 'chmod +x ~/amipkg-publisher/nightly-publish.sh && mkdir -p ~/.config/systemd/user'
scp -q "$HERE/amipkg-nightly.service" "$HERE/amipkg-nightly.timer" "$PI:~/.config/systemd/user/"
ssh "$PI" 'systemctl --user daemon-reload && systemctl --user enable --now amipkg-nightly.timer && loginctl enable-linger loki 2>/dev/null || true
  systemctl --user list-timers amipkg-nightly.timer --no-pager | head -3'

echo "6/6 smoke run"
ssh "$PI" 'sh ~/amipkg-publisher/nightly-publish.sh; tail -3 ~/amipkg-publisher/logs/nightly-$(date +%Y%m%d).log'
echo "DONE — the catalog publishes itself nightly at 03:10 from the Pi."
