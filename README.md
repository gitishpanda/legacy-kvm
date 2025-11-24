# legacy-kvm
# Docker Container for Legacy Avocent KVM (Avocent 3200)

This repository contains a Docker environment pre-configured with Firefox 52 ESR, Java 8, and IcedTea-Web. It allows access to the web interface and Java KVM consoles of legacy hardware like the **Avocent AV3200**, which fail to load on modern systems due to "weak" security algorithms (MD5, SSLv3, RC4).

## Features
- **Firefox 52 ESR**: The last version to support NPAPI plugins and legacy web standards.
- **Java 8 (OpenJDK)**: Pre-configured to allow legacy encryption algorithms.
- **IcedTea-Web**: Open-source replacement for Java Web Start.
- **VNC Access**: The container exposes a VNC server so you can view the browser remotely.
- **Security Fixes**: Automatically patches `java.security` to allow MD5/SHA1 signatures required by old KVM switches.

## Usage

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YOUR_USERNAME/avocent-kvm-docker.git](https://github.com/YOUR_USERNAME/avocent-kvm-docker.git)
   cd avocent-kvm-docker

2. Configure the environment: Edit docker-compose.yaml and/or populate the supplied .env file with your configuration.

    KVM_URL: The URL of your KVM switch (e.g., https://192.168.1.50).
    VNC_PASSWORD: Password for VNC access.

3. Run the container:
    docker-compose up --build -d

4. Connect:
    Connect to vnc://localhost:6080 using your VNC client (e.g. vncviewer localhost:6080)
    You should see Firefox opening your KVM login page.
    Log in and launch the KVM viewer.

How it works

Modern Java versions block JAR files signed with MD5 or SHA1, causing SIGNED_NOT_OK errors. This image modifies /usr/lib/jvm/java-1.8-openjdk/jre/lib/security/java.security to remove MD5, RC4, and DSA from the disabledAlgorithms list, allowing the legacy applets to run.

Troubleshooting

If the KVM applet fails to load or says "Cancelled on user request," try restarting the container to clear the IcedTea cache:
docker-compose restart

