#!/usr/bin/env bash
set -euo pipefail

sudo tee /etc/yum.repos.d/grafana.repo >/dev/null <<'EOF'
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo dnf -y install grafana
sudo systemctl enable grafana-server

sudo mkdir -p /etc/grafana/provisioning/datasources
sudo mkdir -p /etc/grafana/provisioning/dashboards
sudo mkdir -p /var/lib/grafana/dashboards

sudo install -m 0644 ./grafana/provisioning/datasources/datasource.yml /etc/grafana/provisioning/datasources/datasource.yml
sudo install -m 0644 ./grafana/provisioning/dashboards/dashboard.yml /etc/grafana/provisioning/dashboards/dashboard.yml
sudo install -m 0644 ./grafana/dashboards/ysql-overview.json /var/lib/grafana/dashboards/ysql-overview.json

sudo systemctl restart grafana-server
