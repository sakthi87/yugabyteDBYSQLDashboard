#!/usr/bin/env bash
set -euo pipefail

EXPORTER_VERSION="0.15.0"

sudo useradd -r -s /sbin/nologin ybexporter || true
sudo mkdir -p /etc/yb
sudo chown -R ybexporter:ybexporter /etc/yb

if [ ! -x /usr/local/bin/postgres_exporter ]; then
  curl -L -o /tmp/postgres_exporter.tar.gz \
    "https://github.com/prometheus-community/postgres_exporter/releases/download/v${EXPORTER_VERSION}/postgres_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz"
  tar -xzf /tmp/postgres_exporter.tar.gz -C /tmp
  sudo mv "/tmp/postgres_exporter-${EXPORTER_VERSION}.linux-amd64/postgres_exporter" /usr/local/bin/
  sudo chmod +x /usr/local/bin/postgres_exporter
fi

sudo install -m 0644 ./pg_exporter.service /etc/systemd/system/pg_exporter.service
sudo install -m 0644 ./pg_exporter.env.example /etc/yb/pg_exporter.env
sudo install -m 0644 ./queries.yaml /etc/yb/queries.yaml
sudo chown ybexporter:ybexporter /etc/yb/pg_exporter.env /etc/yb/queries.yaml

sudo systemctl daemon-reload
sudo systemctl enable pg_exporter
sudo systemctl restart pg_exporter
