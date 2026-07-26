#!/bin/sh
# setup-trashcan.sh — ONE command on your MacBook deploys the whole
# automated publisher to the Trashcan. Safe to re-run.
set -eu
TC=loki@192.168.178.177
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "1/5 payload (scripts + launchd plist)"
scp -q "$HERE/nightly-publish.sh" "$TC:~/amipkg-publisher/nightly-publish.sh"
scp -q "$HERE/com.amipkg.nightly.plist" "$TC:~/Library/LaunchAgents/com.amipkg.nightly.plist"
ssh "$TC" 'chmod +x ~/amipkg-publisher/nightly-publish.sh && mkdir -p ~/amipkg-publisher/logs'

echo "2/5 SIGNING KEY (the deliberate step)"
scp -q "$HOME/Desktop/amiga-imager-repo/SIGNING-KEY-KEEP-OFFLINE.txt" "$TC:~/amipkg-publisher/signing-key.txt"
ssh "$TC" 'chmod 600 ~/amipkg-publisher/signing-key.txt'

echo "3/5 deploy key (write access for the nightly push)"
ssh "$TC" 'test -f ~/.ssh/amipkg_deploy || ssh-keygen -t ed25519 -N "" -C amipkg-nightly@trashcan -f ~/.ssh/amipkg_deploy -q
  grep -q "Host amiga-pkg-github" ~/.ssh/config 2>/dev/null || printf "\nHost amiga-pkg-github\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/amipkg_deploy\n  IdentitiesOnly yes\n" >> ~/.ssh/config
  cat ~/.ssh/amipkg_deploy.pub' > /tmp/amipkg_deploy.pub
gh repo deploy-key add /tmp/amipkg_deploy.pub --repo thomas-luebker/amiga-pkg --title "trashcan nightly publisher" --allow-write 2>/dev/null || echo "  (deploy key already registered)"

echo "4/5 repo clone"
ssh "$TC" 'test -d ~/amipkg-publisher/amiga-pkg || git clone -q https://github.com/thomas-luebker/amiga-pkg.git ~/amipkg-publisher/amiga-pkg
  cd ~/amipkg-publisher/amiga-pkg && git remote set-url --push origin amiga-pkg-github:thomas-luebker/amiga-pkg.git'

echo "5/5 arm the nightly + smoke test"
ssh "$TC" 'launchctl bootout gui/501/com.amipkg.nightly 2>/dev/null || true
  launchctl bootstrap gui/501 ~/Library/LaunchAgents/com.amipkg.nightly.plist
  sh ~/amipkg-publisher/nightly-publish.sh && tail -3 ~/amipkg-publisher/logs/nightly-$(date +%Y%m%d).log'
echo "DONE - the catalog now publishes itself nightly at 03:10."
