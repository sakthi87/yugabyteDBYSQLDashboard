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
AZ_UATS_NODE1, AZ_UATS_NODE2, AZ_UATS_NODE3
X_CENTRAL_NODE1, X_CENTRAL_NODE2, X_CENTRAL_NODE3
X_EAST_NODE1, X_EAST_NODE2, X_EAST_NODE3
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

### 9) Universe and node filters
The dashboard now uses a `universe` label added in `prometheus.yml`.
If you add a new universe, copy one of the scrape jobs and update:
- `job_name`
- `targets`
- `relabel_configs.replacement`

### 10) Metrics reference (what each metric represents)

| Metric | Source | How it’s extracted | What it means |
|---|---|---|---|
| `pg_stat_statements_calls_total` | `pg_stat_statements` | Exporter built-in stat_statements collector | Total executions per `queryid` (counter). |
| `pg_stat_statements_seconds_total` | `pg_stat_statements` | Exporter built-in stat_statements collector | Total execution time per `queryid` in seconds (counter). |
| `pg_stat_statements_query_id` | `pg_stat_statements` | Exporter built-in stat_statements collector | Maps `queryid` → query text (label). |
| `yb_statements_latency_le_count` | `pg_stat_statements.yb_latency_histogram` | Custom `queries.yaml` converts JSON histogram to Prometheus buckets | Histogram buckets (ms) for latency; used for p50/p95/p99. |
| `yb_statements_op_exec_avg_exec_ms` | `pg_stat_statements.mean_exec_time` | Custom `queries.yaml` | Avg exec time per SQL type (ms). |
| `yb_statements_op_exec_min_exec_ms` | `pg_stat_statements.min_exec_time` | Custom `queries.yaml` | Min exec time per SQL type (ms). |
| `yb_statements_op_exec_max_exec_ms` | `pg_stat_statements.max_exec_time` | Custom `queries.yaml` | Max exec time per SQL type (ms). |
| `handler_latency_yb_tserver_PgClientService_Perform{quantile="mean"}` | TServer `/prometheus-metrics` | Native Yugabyte metrics | YBA-style avg latency (microseconds). |
| `handler_latency_yb_tserver_PgClientService_Perform{quantile="p99"}` | TServer `/prometheus-metrics` | Native Yugabyte metrics | YBA-style p99 latency (microseconds). |
