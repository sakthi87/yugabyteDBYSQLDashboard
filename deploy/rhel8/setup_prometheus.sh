#!/usr/bin/env bash
set -euo pipefail

PROM_VERSION="2.52.0"

sudo useradd -r -s /sbin/nologin prometheus || true
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

if [ ! -x /usr/local/bin/prometheus ]; then
  curl -L -o /tmp/prometheus.tar.gz \
    "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
  tar -xzf /tmp/prometheus.tar.gz -C /tmp
  sudo mv "/tmp/prometheus-${PROM_VERSION}.linux-amd64/prometheus" /usr/local/bin/
  sudo chmod +x /usr/local/bin/prometheus
fi

sudo install -m 0644 ./prometheus.yml /etc/prometheus/prometheus.yml
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
sudo install -m 0644 ./prometheus.service /etc/systemd/system/prometheus.service

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl restart prometheus
