FROM alpine:3.8

# Install minimal dependencies for Firefox and Java
RUN apk add --no-cache \
    firefox-esr=52.9.0-r0 \
    openjdk8-jre \
    icedtea-web \
    x11vnc \
    xvfb \
    openbox \
    supervisor \
    dbus \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# --- ADD THIS BLOCK ---
# 1. echo "" fixes the potential "dangling backslash" at the end of the original file
# 2. Then we append the empty properties to enable MD5, SHA1, RC4, etc.
RUN echo "" >> /usr/lib/jvm/java-1.8-openjdk/jre/lib/security/java.security && \
    echo "jdk.jar.disabledAlgorithms=" >> /usr/lib/jvm/java-1.8-openjdk/jre/lib/security/java.security && \
    echo "jdk.tls.disabledAlgorithms=" >> /usr/lib/jvm/java-1.8-openjdk/jre/lib/security/java.security && \
    echo "jdk.certpath.disabledAlgorithms=" >> /usr/lib/jvm/java-1.8-openjdk/jre/lib/security/java.security

# ----------------------

# Create a non-root user
RUN addgroup -g 1001 kvmuser && \
    adduser -D -u 1001 -G kvmuser kvmuser

# Create config directory
RUN mkdir -p /config && chown -R kvmuser:kvmuser /config

# Configure IcedTea-Web to allow HTTP->HTTPS redirects and handle malformed XML
RUN mkdir -p /home/kvmuser/.config/icedtea-web && \
    echo 'deployment.security.askgrantdialog.show=false' > /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo 'deployment.security.askgrantdialog.notinca=false' >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo 'deployment.security.level=ALLOW_UNSIGNED' >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo 'deployment.security.jsse.hostmismatch.warning=false' >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo 'deployment.manifest.attributes.check=NONE' >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo "deployment.security.revocation.check=NO_CHECK" >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo "deployment.security.validation.ocsp=false" >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo "deployment.security.validation.crl=false" >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo "deployment.security.notinca.warning=false" >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    echo "deployment.security.validity.expired.warning=false" >> /home/kvmuser/.config/icedtea-web/deployment.properties && \
    chown -R kvmuser:kvmuser /home/kvmuser/.config

# Setup VNC with configurable password
RUN mkdir -p /home/kvmuser/.vnc && \
    chown -R kvmuser:kvmuser /home/kvmuser

# Copy VNC password script
COPY scripts/setup-vnc.sh /home/kvmuser/setup-vnc.sh
RUN chmod +x /home/kvmuser/setup-vnc.sh && \
    chown kvmuser:kvmuser /home/kvmuser/setup-vnc.sh

# Default VNC password
ENV VNC_PASSWORD=kvm

# Configure Firefox to auto-open JNLP files with javaws
RUN mkdir -p /home/kvmuser/.mozilla/firefox/default.profile && \
    echo '[General]' > /home/kvmuser/.mozilla/firefox/profiles.ini && \
    echo 'StartWithLastProfile=1' >> /home/kvmuser/.mozilla/firefox/profiles.ini && \
    echo '' >> /home/kvmuser/.mozilla/firefox/profiles.ini && \
    echo '[Profile0]' >> /home/kvmuser/.mozilla/firefox/profiles.ini && \
    echo 'Name=default' >> /home/kvmuser/.mozilla/firefox/profiles.ini && \
    echo 'IsRelative=1' >> /home/kvmuser/.mozilla/firefox/profiles.ini && \
    echo 'Path=default.profile' >> /home/kvmuser/.mozilla/firefox/profiles.ini && \
    echo 'Default=1' >> /home/kvmuser/.mozilla/firefox/profiles.ini && \
    chown -R kvmuser:kvmuser /home/kvmuser/.mozilla

# Create prefs.js for Firefox configuration
RUN echo 'user_pref("browser.download.useDownloadDir", true);' > /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("browser.download.folderList", 2);' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("browser.download.dir", "/home/kvmuser/Downloads");' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("browser.helperApps.neverAsk.saveToDisk", "");' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("browser.helperApps.neverAsk.openFile", "");' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("browser.helperApps.alwaysAsk.force", false);' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("browser.download.manager.showWhenStarting", false);' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("browser.download.manager.showAlertOnComplete", false);' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("plugin.state.java", 2);' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    echo 'user_pref("plugin.scan.plid.all", false);' >> /home/kvmuser/.mozilla/firefox/default.profile/prefs.js && \
    chown -R kvmuser:kvmuser /home/kvmuser/.mozilla

# Create mimeTypes.rdf for JNLP file handling with wrapper script - handle multiple MIME types
RUN echo '<?xml version="1.0"?>' > /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '<RDF:RDF xmlns:NC="http://home.netscape.com/NC-rdf#" xmlns:RDF="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  <RDF:Description RDF:about="urn:mimetype:application/x-java-jnlp-file" NC:value="application/x-java-jnlp-file" NC:editable="true" NC:fileExtensions="jnlp">' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '    <NC:handlerProp RDF:resource="urn:mimetype:handler:application/x-java-jnlp-file"/>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  </RDF:Description>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  <RDF:Description RDF:about="urn:mimetype:handler:application/x-java-jnlp-file" NC:alwaysAsk="false" NC:saveToDisk="false" NC:useSystemDefault="false" NC:handleInternal="false">' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '    <NC:externalApplication RDF:resource="urn:mimetype:externalApplication:application/x-java-jnlp-file"/>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  </RDF:Description>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  <RDF:Description RDF:about="urn:mimetype:externalApplication:application/x-java-jnlp-file" NC:prettyName="Java Web Start" NC:path="/usr/local/bin/javaws-wrapper"/>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  <RDF:Description RDF:about="urn:mimetype:application/octet-stream" NC:value="application/octet-stream" NC:editable="true" NC:fileExtensions="jnlp,cgi">' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '    <NC:handlerProp RDF:resource="urn:mimetype:handler:application/octet-stream"/>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  </RDF:Description>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  <RDF:Description RDF:about="urn:mimetype:handler:application/octet-stream" NC:alwaysAsk="false" NC:saveToDisk="false" NC:useSystemDefault="false" NC:handleInternal="false">' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '    <NC:externalApplication RDF:resource="urn:mimetype:externalApplication:application/octet-stream"/>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  </RDF:Description>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '  <RDF:Description RDF:about="urn:mimetype:externalApplication:application/octet-stream" NC:prettyName="Java Web Start" NC:path="/usr/local/bin/javaws-wrapper"/>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    echo '</RDF:RDF>' >> /home/kvmuser/.mozilla/firefox/default.profile/mimeTypes.rdf && \
    chown -R kvmuser:kvmuser /home/kvmuser/.mozilla

# Create mimeapps.list to associate JNLP with javaws  
RUN mkdir -p /home/kvmuser/.local/share/applications && \
    echo '[Default Applications]' > /home/kvmuser/.local/share/applications/mimeapps.list && \
    echo 'application/x-java-jnlp-file=javaws.desktop' >> /home/kvmuser/.local/share/applications/mimeapps.list && \
    chown -R kvmuser:kvmuser /home/kvmuser/.local

# Create javaws wrapper script to enable redirects and verbose output
RUN echo '#!/bin/sh' > /usr/local/bin/javaws-wrapper && \
    echo 'exec /usr/lib/jvm/java-1.8-openjdk/bin/javaws -Xnofork -allowredirect -verbose "$@"' >> /usr/local/bin/javaws-wrapper && \
    chmod +x /usr/local/bin/javaws-wrapper

# Copy start-firefox.sh into the container
COPY scripts/start-firefox.sh /home/kvmuser/start-firefox.sh
RUN chmod +x /home/kvmuser/start-firefox.sh && \
    chown kvmuser:kvmuser /home/kvmuser/start-firefox.sh

# Environment variable for KVM URL
ENV KVM_URL=https://kvm.wellstech.work

# Create supervisord config
RUN mkdir -p /etc/supervisor/conf.d
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set display
ENV DISPLAY=:0
ENV JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk

# Expose VNC port
EXPOSE 5900

USER kvmuser
WORKDIR /home/kvmuser

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-u", "kvmuser"]

