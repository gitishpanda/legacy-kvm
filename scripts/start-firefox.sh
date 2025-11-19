#!/bin/sh
export DISPLAY=:0

# Initialize config directory on first run
if [ ! -d /config/.mozilla ]; then
  echo "First run: initializing Firefox profile in /config"
  cp -r /home/kvmuser/.mozilla /config/
  cp -r /home/kvmuser/.local /config/
  cp -r /home/kvmuser/.config /config/
fi

# Create downloads directory
mkdir -p /config/downloads

# Copy fresh mimeTypes.rdf and prefs.js on every start to ensure handlers are registered
cp /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf /config/.mozilla/firefox/default.profile/mimeTypes.rdf

# Ensure JNLP handler is in prefs.js
if ! grep -q "browser.helperApps.neverAsk.openFile" /config/.mozilla/firefox/default.profile/prefs.js; then
  echo 'user_pref("browser.helperApps.neverAsk.openFile", "application/x-java-jnlp-file");' >> /config/.mozilla/firefox/default.profile/prefs.js
fi

# Link config directories to persistent volume
rm -rf /home/kvmuser/.mozilla /home/kvmuser/.local /home/kvmuser/.config/icedtea-web
ln -sf /config/.mozilla /home/kvmuser/.mozilla
ln -sf /config/.local /home/kvmuser/.local
ln -sf /config/.config/icedtea-web /home/kvmuser/.config/icedtea-web
ln -sf /config/downloads /home/kvmuser/Downloads

# Auto-launch watcher for downloaded JNLP files - watch both /config/downloads and /tmp
echo "Starting file watcher..."
(while true; do
  for f in /config/downloads/*.jnlp /config/downloads/*.cgi /tmp/mozilla_*/*.jnlp /tmp/mozilla_*/*.cgi; do
    if [ -f "$f" ]; then
      echo "Auto-launching: $f"
      /usr/local/bin/javaws-wrapper "$f" &
      sleep 2
      rm -f "$f"
    fi
  done
  sleep 1
done) &
WATCHER_PID=$!
echo "File watcher started with PID: $WATCHER_PID"

openbox &
sleep 2
firefox "${KVM_URL:-about:blank}"
