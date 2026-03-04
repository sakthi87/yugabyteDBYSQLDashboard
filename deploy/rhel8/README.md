## RHEL8 3-node YugabyteDB monitoring deployment (runbook)

This is a copy-paste runbook. Follow in order.

### 0) Decide hostnames/IPs
Set these before starting:
- `NODE1`, `NODE2`, `NODE3` = YB TServer node IP/hostname
- `PROM_HOST` = Prometheus/Grafana host

### 1) Enable pg_stat_statements (YBA)
Set gflag in YBA and restart the universe:
```
ysql_pg_conf=shared_preload_libraries=pg_stat_statements
```
Then connect to YSQL (once) and run:
```
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

### 2) Create exporter user (once)
```
CREATE USER yb_exporter WITH PASSWORD 'strongpass';
GRANT CONNECT ON DATABASE yugabyte TO yb_exporter;
GRANT pg_monitor TO yb_exporter;
```

### 3) Install postgres_exporter on each node
On each node (NODE1, NODE2, NODE3):

1) Copy files to the node:
```
queries.yaml
pg_exporter.env.example
pg_exporter.service
setup_pg_exporter.sh
```

2) Create `/etc/yb/pg_exporter.env`:
```
sudo mkdir -p /etc/yb
sudo cp pg_exporter.env.example /etc/yb/pg_exporter.env
sudo sed -i 's/strongpass/<YOUR_PASSWORD>/g' /etc/yb/pg_exporter.env
```

3) Run installer:
```
chmod +x setup_pg_exporter.sh
sudo ./setup_pg_exporter.sh
```

4) Verify:
```
systemctl status pg_exporter --no-pager
curl -s http://127.0.0.1:9187/metrics | head
```

### 4) Install Prometheus on PROM_HOST
On PROM_HOST:

1) Copy files:
```
prometheus.yml
prometheus.service
setup_prometheus.sh
```

2) Edit `prometheus.yml` and replace:
```
NODE1, NODE2, NODE3
```

3) Run installer:
```
chmod +x setup_prometheus.sh
sudo ./setup_prometheus.sh
```

4) Verify:
```
systemctl status prometheus --no-pager
curl -s http://localhost:9090/-/ready
```

### 5) Install Grafana on PROM_HOST (or separate host)
On Grafana host:

1) Copy files:
```
grafana/provisioning/datasources/datasource.yml
grafana/provisioning/dashboards/dashboard.yml
grafana/dashboards/ysql-overview.json
setup_grafana.sh
```

2) Edit `grafana/provisioning/datasources/datasource.yml` and replace:
```
PROM_HOST -> Prometheus host
NODE1 -> any YSQL node
```

3) Run installer:
```
chmod +x setup_grafana.sh
sudo ./setup_grafana.sh
```

4) Verify:
```
systemctl status grafana-server --no-pager
```

Grafana: `http://<grafana-host>:3000` (admin/admin).

### 6) Firewall rules (if enabled)
Open inbound on PROM_HOST:
- `3000/tcp` Grafana
- `9090/tcp` Prometheus

Open inbound on all YB nodes (from PROM_HOST only):
- `9187/tcp` postgres_exporter
- `9000/tcp` tserver metrics
- `7000/tcp` master metrics

### 7) Validate in Prometheus
In Prometheus UI, check:
- `up{job="postgres-exporter"}`
- `yb_statements_latency_le_count`

### 8) Validate in Grafana
Open dashboard: `YugabyteDB YSQL Overview`.
