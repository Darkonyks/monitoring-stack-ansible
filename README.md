# Monitoring Stack: Prometheus + Node Exporter + Docker Volumes Metrics (Automation & Ansible)

This repository provides a production-friendly setup for:
- **Prometheus** (collector) — runs on `serv12`
- **Node Exporter** — runs on `sremgas-geonode` (and any other hosts)
- **Custom Docker Volumes metrics** via Node Exporter **textfile collector** on `sremgas-geonode`
- **Systemd watchdogs** (Prometheus & Node Exporter) for auto-healing
- **Ansible playbook** to deploy the whole stack to the appropriate hosts

> Prometheus and Node Exporter live on **different servers**. Timers/services are split accordingly.

---

## Architecture

```
serv12 (Prometheus)
└─ /etc/systemd/system/prometheus.service  (Restart=always)
└─ /usr/local/bin/prometheus-watchdog.sh   +  watchdog timer

sremgas-geonode (Node Exporter + Docker volumes metrics)
└─ /etc/systemd/system/node_exporter.service  (Restart=always, textfile collector)
└─ /usr/local/bin/docker-volumes-metrics.sh   (whitelist: sremgas-*)
└─ /etc/systemd/system/docker-volumes-metrics.{service,timer}
└─ /usr/local/bin/node-exporter-watchdog.sh   +  watchdog timer
```

---

## Quickstart (Manual)

### Prometheus (on **serv12**)
```bash
VER="2.52.0"  # latest stable v2.x is recommended
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${VER}/prometheus-${VER}.linux-amd64.tar.gz
tar -xzf prometheus-${VER}.linux-amd64.tar.gz
sudo mv prometheus-${VER}.linux-amd64/prometheus /usr/local/bin/
sudo mv prometheus-${VER}.linux-amd64/promtool /usr/local/bin/
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo mv prometheus-${VER}.linux-amd64/{consoles,console_libraries} /etc/prometheus/
sudo useradd --no-create-home --shell /bin/false prometheus || true
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo cp prometheus/prometheus.yml /etc/prometheus/prometheus.yml
sudo cp prometheus/prometheus.service /etc/systemd/system/prometheus.service
sudo systemctl daemon-reload && sudo systemctl enable --now prometheus
```

### Node Exporter (on **sremgas-geonode**)
```bash
VER="1.9.1"
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${VER}/node_exporter-${VER}.linux-amd64.tar.gz
tar -xzf node_exporter-${VER}.linux-amd64.tar.gz
sudo mv node_exporter-${VER}.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /bin/false node_exporter || true
sudo mkdir -p /var/lib/node_exporter/textfile
sudo chown -R node_exporter:node_exporter /var/lib/node_exporter
sudo cp node_exporter/node_exporter.service /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload && sudo systemctl enable --now node_exporter
```

### Docker Volumes Metrics (on **sremgas-geonode**)
```bash
sudo cp docker-volumes-metrics/docker-volumes-metrics.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-volumes-metrics.sh
sudo cp docker-volumes-metrics/docker-volumes-metrics.service /etc/systemd/system/
sudo cp docker-volumes-metrics/docker-volumes-metrics.timer /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now docker-volumes-metrics.timer
```
Verify:
```bash
sudo /usr/local/bin/docker-volumes-metrics.sh
ls -lh /var/lib/node_exporter/textfile/docker_volumes.prom
curl -s http://localhost:9100/metrics | grep docker_volume_size_bytes | head
```

### Watchdogs
**Node Exporter watchdog** (on `sremgas-geonode`):
```bash
sudo cp watchdogs/node-exporter-watchdog.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/node-exporter-watchdog.sh
sudo cp watchdogs/node-exporter-watchdog.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now node-exporter-watchdog.timer
```

**Prometheus watchdog** (on `serv12`):
```bash
sudo cp watchdogs/prometheus-watchdog.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/prometheus-watchdog.sh
sudo cp watchdogs/prometheus-watchdog.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now prometheus-watchdog.timer
```

---

## Ansible Deployment

### Inventory (`ansible/inventory.ini`)
Adjust hostnames/IPs and SSH users:
```ini
[prometheus_server]
serv12 ansible_host=192.168.5.100 ansible_user=darko

[node_exporter_servers]
sremgas-geonode ansible_host=192.168.5.22 ansible_user=administrator
```

### Variables (`ansible/vars/main.yml`)
```yaml
prometheus_version: "2.52.0"   # stable v2.x
node_exporter_version: "1.9.1"
prometheus_config_path: "/etc/prometheus/prometheus.yml"
docker_metrics_output_dir: "/var/lib/node_exporter/textfile"
```

### Run
```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```
The playbook will:
- Install & configure **Prometheus** on `prometheus_server`
- Install & configure **Node Exporter** on all `node_exporter_servers`
- Install Docker volumes metrics script + timer on all hosts (you can limit this to certain hosts with inventory groups)
- Install watchdogs (Prometheus watchdog only on Prometheus host; Node Exporter watchdog on exporter hosts)

---

## Prometheus config

`prometheus/prometheus.yml` includes:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter"
    static_configs:
      - targets:
        - "192.168.5.22:9100"   # sremgas-geonode
```
Adjust targets as needed (or switch to file_sd if you prefer). Validate with `promtool check config`.

---

## Grafana (optional)

`grafana/import_dashboards.sh` will import JSON dashboards in `grafana/dashboards/` into Grafana:
```bash
export GRAFANA_URL="http://localhost:3000"
export API_KEY="YOUR_GRAFANA_API_KEY"
./grafana/import_dashboards.sh
```
Replace `API_KEY` with a Grafana API key with `Admin` or `Editor` permissions.

---

## Troubleshooting

- **Prometheus fails to start with `--collector.textfile.directory`**  
  That flag belongs to **node_exporter**, not Prometheus (remove from Prometheus service).

- **Node Exporter `203/EXEC`**  
  Ensure `/usr/local/bin/node_exporter` exists and is executable. Check unit path.

- **No Docker volume metrics**  
  Ensure script writes to `/var/lib/node_exporter/textfile/docker_volumes.prom`.  
  Ensure named volumes exist and match `sremgas-*` filter.  
  Ensure node_exporter service has `--collector.textfile.directory=/var/lib/node_exporter/textfile`.

---

## License
MIT
