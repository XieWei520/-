# Server Connection Capacity Tuning Rollout Report

## Baseline

### Host Snapshot
```text
host ulimit -n: 1024
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 512
net.netfilter.nf_conntrack_max = 262144
net.ipv4.tcp_keepalive_time = 7200
net.ipv4.tcp_keepalive_intvl = 75
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.ip_local_port_range = 32768 60999
baseline ss -s:
Total: 721
TCP: 108 (estab 10, closed 72, orphaned 2, timewait 0)
UDP: 331
TCP transport entries: 36
INET: 367
```

### Container Snapshot
```text
wukongim ulimit -n: 1048576
nginx ulimit -n: 1048576
tsdd-api ulimit -n: 1048576
```
- Note: the original baseline capture predated Task 3's four-service recreate check, so `callgateway` was validated in the post-change runtime verification instead of the initial snapshot.

### Compose Snapshot
```text
Pre-change compose status: callgateway/nginx/tsdd-api/wukongim were up (healthy where defined).
mysql/minio/redis were healthy. coturn/livekit were up.
```

## Backups
- rollback directory: /opt/wukongim-prod/rollback_snapshots/task2_connection_capacity_20260423_192620
- backed up: /opt/wukongim-prod/src/deploy/production/docker-compose.yaml
- backed up: /etc/sysctl.conf -> /opt/wukongim-prod/rollback_snapshots/task2_connection_capacity_20260423_192620/sysctl.conf.bak
- backed up if present: /etc/sysctl.d/99-wukongim-connection-capacity.conf
- observed during backup: existing /etc/sysctl.d/99-wukongim-connection-capacity.conf was not present

## Applied Changes

### Host Sysctl File
```text
/etc/sysctl.d/99-wukongim-connection-capacity.conf
fs.file-max = 1048576
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.netfilter.nf_conntrack_max = 524288
```

### Apply Notes
- Ran `sudo sysctl --system` first per task instructions.
- `/etc/sysctl.conf` contained an overriding `net.core.somaxconn = 4096` entry, which overrode the new `/etc/sysctl.d/99-wukongim-connection-capacity.conf` value.
- Backed up and corrected `/etc/sysctl.conf` to `net.core.somaxconn = 65535` for persistence, then re-ran `sudo sysctl --system`.
- Verified `net.core.somaxconn = 65535` still holds after `sysctl --system`.

### Compose `ulimits` (explicit in Compose)
- `nginx`: `nofile soft/hard 1048576`
- `wukongim`: `nofile soft/hard 1048576`
- `tsdd-api`: `nofile soft/hard 1048576`
- `callgateway`: `nofile soft/hard 1048576`

## Post-Change Verification

### Final Operational Verification
```text
host ulimit -n = 1024
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384
net.netfilter.nf_conntrack_max = 524288
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_fin_timeout = 15
fs.file-max = 1048576
```

### Compose and Service Health (`docker compose --env-file .env ps`)
```text
NAME                          IMAGE                                                                                 COMMAND                  SERVICE       CREATED          STATUS                    PORTS
wukongim_prod-callgateway-1   wukongim/tsdd-api:production-local                                                    "/home/app callgatew…"   callgateway   12 minutes ago   Up 12 minutes (healthy)
wukongim_prod-coturn-1        coturn/coturn:4.7.0-r2                                                                "docker-entrypoint.s…"   coturn        2 weeks ago      Up 2 weeks                0.0.0.0:3478->3478/tcp, [::]:3478->3478/tcp, 0.0.0.0:3478->3478/udp, [::]:3478->3478/udp, 0.0.0.0:5349->5349/tcp, [::]:5349->5349/tcp, 0.0.0.0:49160-49220->49160-49220/udp, [::]:49160-49220->49160-49220/udp, 5349/udp
wukongim_prod-livekit-1       livekit/livekit-server:v1.9.8                                                         "/livekit-server --c…"   livekit       2 weeks ago      Up 2 weeks                0.0.0.0:7881->7881/tcp, [::]:7881->7881/tcp, 0.0.0.0:50000-50100->50000-50100/udp, [::]:50000-50100->50000-50100/udp
wukongim_prod-minio-1         minio/minio@sha256:14cea493d9a34af32f524e538b8346cf79f3321eff8e708c1e2960462bd8936e   "/usr/bin/docker-ent…"   minio         2 weeks ago      Up 2 weeks (healthy)      9000/tcp
wukongim_prod-mysql-1         mysql:8.0                                                                             "docker-entrypoint.s…"   mysql         2 weeks ago      Up 2 weeks (healthy)      3306/tcp, 33060/tcp
wukongim_prod-nginx-1         nginx:1.27-alpine                                                                     "/docker-entrypoint.…"   nginx         12 minutes ago   Up 11 minutes             0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp
wukongim_prod-redis-1         redis:7-alpine                                                                        "docker-entrypoint.s…"   redis         2 weeks ago      Up 2 weeks (healthy)      6379/tcp
wukongim_prod-tsdd-api-1      wukongim/tsdd-api:production-local                                                    "/home/app api"          tsdd-api      12 minutes ago   Up 12 minutes (healthy)
wukongim_prod-wukongim-1      registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2                                "/home/app --config=…"   wukongim      12 minutes ago   Up 12 minutes (healthy)   0.0.0.0:5100->5100/tcp, [::]:5100->5100/tcp, 127.0.0.1:5001->5001/tcp, 0.0.0.0:5200->5200/tcp, [::]:5200->5200/tcp
```

### Container Verification
```text
wukongim container ulimit -n = 1048576
nginx container ulimit -n = 1048576
tsdd-api container ulimit -n = 1048576
callgateway container ulimit -n = 1048576
```

### Socket Summary (`ss -s`)
```text
Total: 664
TCP: 109 (estab 7, closed 76, orphaned 2, timewait 0)
UDP: 331
TCP: 33 in transport table
INET: 364
```

### Gateway Logs
- No new startup or configuration errors after recreate.
- Logs show successful server startup.
- Malformed raw-IP HTTP probes are still present on the TCP port; this is external noise and not a regression from this slice.

### Before/After Comparison
- host `ulimit -n`: `1024` -> `1024` (interactive shell unchanged; tuning is kernel and container focused)
- `net.core.somaxconn`: `4096` -> `65535`
- `net.ipv4.tcp_max_syn_backlog`: `512` -> `16384`
- `net.netfilter.nf_conntrack_max`: `262144` -> `524288`
- `net.ipv4.tcp_keepalive_time`: `7200` -> `120`
- `net.ipv4.tcp_keepalive_intvl`: `75` -> `30`
- `net.ipv4.tcp_keepalive_probes`: `9` -> `5`
- `net.ipv4.ip_local_port_range`: `32768 60999` -> `10240 65535`
- `wukongim` container `ulimit -n`: `1048576` -> `1048576` (now explicit in Compose)

## Rollback Notes
- Restore `/opt/wukongim-prod/rollback_snapshots/task2_connection_capacity_20260423_192620/docker-compose.yaml.bak` to `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`.
- Restore `/opt/wukongim-prod/rollback_snapshots/task2_connection_capacity_20260423_192620/sysctl.conf.bak` to `/etc/sysctl.conf`.
- Remove or restore `/etc/sysctl.d/99-wukongim-connection-capacity.conf`.
- Run `sudo sysctl --system`.
- Run `docker compose --env-file .env up -d --force-recreate nginx wukongim tsdd-api callgateway`.

## Non-Goals Confirmed
- `/v1/users/{uid}/im` contract was not changed.
- No MySQL schema or index changes were made.
- No Redis data model changes were made.
- Ports `5100` and `5200` remain open in this slice.
- Cluster mode is still disabled.
