# Server Connection Capacity Tuning Rollout Report

## Baseline

### Host Limits
```text
1024
---
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 512
net.netfilter.nf_conntrack_max = 262144
net.ipv4.tcp_keepalive_time = 7200
net.ipv4.tcp_keepalive_intvl = 75
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.ip_local_port_range = 32768	60999
---
               total        used        free      shared  buff/cache   available
Mem:           7.5Gi       2.1Gi       940Mi       2.7Mi       4.8Gi       5.4Gi
Swap:          1.9Gi       1.9Gi       392Ki
---
Total: 721
TCP:   108 (estab 10, closed 72, orphaned 2, timewait 0)

Transport Total     IP        IPv6
RAW	  0         0         0        
UDP	  331       167       164      
TCP	  36        28        8        
INET	  367       195       172      
FRAG	  0         0         0
```

### Container Limits
```text
1048576
---
1048576
---
1048576
```

### Compose Status
```text
NAME                          IMAGE                                                                                 COMMAND                  SERVICE       CREATED       STATUS                 PORTS
wukongim_prod-callgateway-1   sha256:e494bd9ea794c3e5a842803e03e8bd236e989b2a8ca6dda25005db9056238f89               "/home/app callgatew…"   callgateway   6 hours ago   Up 6 hours (healthy)   
wukongim_prod-coturn-1        coturn/coturn:4.7.0-r2                                                                "docker-entrypoint.s…"   coturn        2 weeks ago   Up 2 weeks             0.0.0.0:3478->3478/tcp, [::]:3478->3478/tcp, 0.0.0.0:3478->3478/udp, [::]:3478->3478/udp, 0.0.0.0:5349->5349/tcp, 0.0.0.0:49160-49220->49160-49220/udp, [::]:5349->5349/tcp, [::]:49160-49220->49160-49220/udp, 5349/udp
wukongim_prod-livekit-1       livekit/livekit-server:v1.9.8                                                         "/livekit-server --c…"   livekit       2 weeks ago   Up 2 weeks             0.0.0.0:7881->7881/tcp, [::]:7881->7881/tcp, 0.0.0.0:50000-50100->50000-50100/udp, [::]:50000-50100->50000-50100/udp
wukongim_prod-minio-1         minio/minio@sha256:14cea493d9a34af32f524e538b8346cf79f3321eff8e708c1e2960462bd8936e   "/usr/bin/docker-ent…"   minio         2 weeks ago   Up 2 weeks (healthy)   9000/tcp
wukongim_prod-mysql-1         mysql:8.0                                                                             "docker-entrypoint.s…"   mysql         2 weeks ago   Up 2 weeks (healthy)   3306/tcp, 33060/tcp
wukongim_prod-nginx-1         nginx:1.27-alpine                                                                     "/docker-entrypoint.…"   nginx         6 hours ago   Up 6 hours             0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp
wukongim_prod-redis-1         redis:7-alpine                                                                        "docker-entrypoint.s…"   redis         2 weeks ago   Up 2 weeks (healthy)   6379/tcp
wukongim_prod-tsdd-api-1      wukongim/tsdd-api:production-local                                                    "/home/app api"          tsdd-api      2 hours ago   Up 2 hours (healthy)   
wukongim_prod-wukongim-1      registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2                                "/home/app --config=…"   wukongim      6 hours ago   Up 6 hours (healthy)   0.0.0.0:5100->5100/tcp, [::]:5100->5100/tcp, 127.0.0.1:5001->5001/tcp, 0.0.0.0:5200->5200/tcp, [::]:5200->5200/tcp
```

## Backups

## Applied Changes

## Post-Change Verification

## Rollback Notes
