# MordorWide Deployment

This repository contains and documents the steps that are needed to deploy the MordorWide stack.

## Initial Deployment Steps

In order to deploy the stack, the following things are required:
- A main Linux server that should host the reimplementation of the EA Nation backend, the web server, and the TURN server.
- The server should have a public IPv4 address
- A domain e.g. 'mordorwi.de' that (partially) points to the IPv4 address
- [Optional] A second server that relays certain packets for STUN/NAT detection.
- [Only required for the web server] A valid SMTP server for the domain.

- The server(s) should have installed 'docker' and its 'docker compose' helper.
- It is assumed that the user is in the group 'docker' to avoid the need for sudo (which effectively(!) bypasses the sudo prompt of the user).
- The relevant port should be opened in the firewall (on the server, as well as in the SDN firewall of the hoster)! This includes:
  - Main Server (with TURN server at range 40000-50000)
    - [TCP] 18885 v4: Theater port
    - [UDP] 18885 v4: Theater port
    - [TCP] 18880 v4: Fesl PC port
    - [TCP] 18870 v4: Fesl PS3 port
    - [TCP] 18860 v4: Fesl XBox 360 port
    - [UDP] 40000-50000 v4: TURN relay ports
  - STUN Relay Server
    - [TCP] 8002 v4: STUN relay control port


In the following, it is assumed that
- the used domain is `mordorwi.de` and,
- `mordorwi.de` and its subdomains point to the IP of the main server,
- `natneg.mordorwi.de` points to the IP of the STUN relay server.
- The firewall for the `natneg.mordorwi.de` server allows access on port 8002 only from the IP of the main server.
- The local machine is running a modern Linux distribution (or within WSL) with git, docker and docker compose, and openssl binaries installed.

The following steps
```bash
# Clone the repositories
./loadMordorWide.sh

# We assume that the user can login to
# - the main server via main@mordorwi.de
# - the STUN server via main@natnet.mordorwi.de

# [Steps to setup the STUN server]
# -> If skipped,
#    - go to the [Steps to setup the main server]
#    - make sure to set STUN_ENABLED=0 during the env.full preparations.

# 1. Prepare the STUN server configuration and update the files if needed
cp env.stunrelay.example env.stunrelay
nano env.stunrelay
nano docker-compose.stunrelay.yml

# 2. Create the directory on the STUN server
ssh main@natneg.mordorwi.de << 'EOF'
set -e
mkdir ~/mordorwide-stun-deployment
EOF

# 3. Build the image
docker compose -f docker-compose.stunrelay.yml build

# 4. Save and upload the image
docker save mordorwide/stunrelay:latest | gzip > img-stunrelay.tar.gz
scp img-stunrelay.tar.gz         main@natneg.mordorwi.de:~/mordorwide-stun-deployment/img-stunrelay.tar.gz

# 5. Upload the env and compose files
scp env.stunrelay                main@natneg.mordorwi.de:~/mordorwide-stun-deployment/env.stunrelay
scp docker-compose.stunrelay.yml main@natneg.mordorwi.de:~/mordorwide-stun-deployment/docker-compose.stunrelay.yml

# 6. Launch the STUN server using docker compose
ssh main@natneg.mordorwi.de << 'EOF'
set -e
cd ~/mordorwide-stun-deployment
docker compose up -d
EOF

# [Steps to setup the main server]
# 1. Generate self-signed certs locally into ssl/ folder
mkdir -p ssl && cd ssl && ../mordorwide-eanation/scripts/generateCertificate.sh && cd ..

# 2. Prepare the STUN server configuration and update the files if needed
cp env.full.example env.full
nano env.full
nano docker-compose.full.yml

# 3. Create the directory on the main server
ssh main@mordorwi.de << 'EOF'
set -e
mkdir ~/mordorwide-deployment
EOF

# 4. Build the images
docker compose -f docker-compose.full.yml build

# 5. Save and upload the images
docker save mordorwide/eanation:latest | gzip > img-eanation.tar.gz
docker save mordorwide/web:latest      | gzip > img-web.tar.gz
docker save mordorwide/udpturn:latest  | gzip > img-udpturn.tar.gz
scp img-eanation.tar.gz main@mordorwi.de:~/mordorwide-deployment/img-eanation.tar.gz
scp img-web.tar.gz      main@mordorwi.de:~/mordorwide-deployment/img-web.tar.gz
scp img-udpturn.tar.gz  main@mordorwi.de:~/mordorwide-deployment/img-udpturn.tar.gz

# 6. Upload the env and compose files
scp env.full                main@mordorwi.de:~/mordorwide-deployment/env.full
scp docker-compose.full.yml main@mordorwi.de:~/mordorwide-deployment/docker-compose.full.yml

# 7. Upload the SSL certs
scp -r ssl main@mordorwi.de:~/mordorwide-deployment/ssl

# 8. Launch the main server using docker compose
ssh main@mordorwi.de << 'EOF'
set -e
cd ~/mordorwide-deployment
docker compose up -d
EOF

# 9. Setup the HTTP(S) reverse proxy to server the web domain to the local web server at 127.0.0.1:8000.

# 10. Setup the database schema. (Choose an actual email address and password!)
ssh main@mordorwi.de << 'EOF'
set -e
sleep 10
docker exec -it mordorwide-web python3 manage.py makemigrations
docker exec -it mordorwide-web python3 manage.py migrate
docker exec -it mordorwide-web python3 manage.py createsuperuser --email my_email@gmail.com --password Hunter2
EOF

# 11. Restart the EA Nation reimplementation in order to re-start well with an initialized database schema.
ssh main@mordorwi.de << 'EOF'
set -e
docker restart mordorwide-eanation
EOF
```