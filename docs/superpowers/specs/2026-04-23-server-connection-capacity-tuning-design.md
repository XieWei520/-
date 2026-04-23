# Server Connection Capacity Tuning Design

**Date:** 2026-04-23

**Goal:** Raise the production IM gateway's long-connection capacity baseline by tuning host kernel/network limits and container file-descriptor limits, while preserving the current single-host deployment topology and existing client/server protocol contract.

## Design Summary

The current production host is functionally healthy but under-tuned for an IM
gateway:

- host `ulimit -n` is only `1024`
- `net.ipv4.tcp_max_syn_backlog = 512`
- `net.ipv4.tcp_keepalive_time = 7200`
- `net.ipv4.ip_local_port_range = 32768 60999`
- `docker inspect ...HostConfig.Ulimits` for `wukongim` is `null`
- runtime container `ulimit -n` is already `1048576` for `wukongim`,
  `nginx`, and `tsdd-api`
- `wukongim` is running single-node, standalone, with `1 event-loop`
- host swap is fully allocated even though RAM headroom still exists

This slice does not try to solve clustering, QoS semantics, or database
latency. It only raises the connection-capacity floor so the current topology
is less likely to fall over under connect bursts, idle mobile clients, and
descriptor pressure.

The implementation will make three coordinated changes:

1. Add a dedicated host sysctl tuning file for socket backlog, conntrack,
   keepalive, and port-range settings
2. Add explicit `nofile` limits to the network-facing Docker services in
   `deploy/production/docker-compose.yaml` so the current high runtime ceiling
   is declared rather than implicit
3. Apply the new settings with backup-first safety steps and verify the before
   and after values on the production host

## Confirmed Current State

Read-only inspection on `ubuntu@42.194.218.158` found:

- host: `VM-0-13-ubuntu`, Ubuntu 6.8 kernel, uptime 22 days
- Docker services: `nginx`, `wukongim`, `tsdd-api`, `callgateway`, `redis`,
  `mysql`, `livekit`, `coturn`, `minio`
- compose file: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
- runtime config: `/opt/wukongim-prod/src/deploy/production/rendered/wk.yaml`
- `rendered/wk.yaml` currently advertises:
  - `tcpAddr: wemx.cc:5100`
  - `wsAddr: ws://wemx.cc:5200`
  - `wssAddr: wss://wemx.cc/ws`
- `nginx/default.conf.template` already proxies `/ws` to `wukongim:5200` and
  redirects all HTTP traffic to HTTPS
- `wukongim` logs still show malformed HTTP probes hitting `42.194.218.158:5100`

## Approaches Considered

### Recommended: Combined host sysctl tuning plus explicit container `nofile`

- tune host backlog, keepalive, conntrack, and ephemeral port range
- set explicit `ulimits.nofile` on the network-facing containers
- recreate only the affected containers after backups

Why this approach:

- fixes both sides of the bottleneck: kernel queueing and process descriptor
  ceilings
- keeps the current deployment model intact
- is measurable immediately with before/after commands
- does not require protocol migration or clustering work

### Rejected: Host-only tuning

This improves backlog and keepalive behavior, but leaves container process
limits implicit and daemon-dependent. Runtime inspection shows the current
containers already have a high ceiling, but that safety is not declared in
Compose and could drift on rebuild or daemon changes.

### Rejected: Container-only tuning

This preserves the current high container descriptor ceiling, but still leaves
`tcp_max_syn_backlog`, `somaxconn`, keepalive, and port-range settings at weak
host defaults.

### Rejected: Skip tuning and jump directly to cluster scaling

The production gateway is still standalone. Introducing cluster work before
raising the single-node baseline would add much more risk and complexity than
benefit.

## Target Behavior

After this slice:

- host socket backlog and conntrack settings are sized for connection bursts
- host keepalive settings detect dead mobile sessions faster than the current
  2-hour Linux default
- the IM gateway container runs with an explicit high `nofile` ceiling
- the current public endpoints remain unchanged:
  - raw TCP `:5100`
  - raw WS `:5200`
  - TLS WS at `https://wemx.cc/ws`
- no client contract or route-discovery payload changes are introduced

## Planned Tuning Values

The exact values to apply in this slice:

- `fs.file-max = 1048576`
- `net.core.somaxconn = 65535`
- `net.ipv4.tcp_max_syn_backlog = 16384`
- `net.ipv4.ip_local_port_range = 10240 65535`
- `net.ipv4.tcp_fin_timeout = 15`
- `net.ipv4.tcp_keepalive_time = 120`
- `net.ipv4.tcp_keepalive_intvl = 30`
- `net.ipv4.tcp_keepalive_probes = 5`
- `net.netfilter.nf_conntrack_max = 524288`

The container-side file-descriptor target for the network-facing services:

- `soft nofile = 1048576`
- `hard nofile = 1048576`

## Scope

This slice includes:

- read-only baseline capture
- mandatory backups of every server file that will be changed
- edits to:
  - `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
  - a new host sysctl file under `/etc/sysctl.d/`
- applying the sysctl changes live
- recreating the affected Docker services to pick up new `ulimits`
- before/after verification of:
  - host sysctl values
  - container `ulimit -n`
  - `docker compose ps`
  - recent gateway logs

## Non-Goals

This slice does not:

- change `/v1/users/{uid}/im` or any route-discovery payload
- change ACK/QoS semantics
- add Redis-backed presence or queueing
- alter MySQL indexes or query plans
- close ports `5100` / `5200` or enforce a new firewall policy
- convert the deployment to cluster mode

## Operational Safety

Before any remote write:

- back up `docker-compose.yaml`
- back up any existing custom sysctl file that overlaps this change
- capture the current kernel values for rollback notes

Rollback must be straightforward:

- restore the compose backup
- remove or restore the sysctl file
- re-run `sysctl --system`
- recreate the affected containers again

## Testing And Verification

The verification set for this slice is operational, not unit-test based:

- `ulimit -n`
- `sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_max net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes net.ipv4.ip_local_port_range`
- `docker exec wukongim_prod-wukongim-1 sh -lc 'ulimit -n'`
- `docker compose --env-file .env ps`
- `ss -s`
- `docker logs --tail 100 wukongim_prod-wukongim-1`

Success for this slice means:

- new sysctl values are active
- container `ulimit -n` reflects the configured high ceiling
- recreated services return healthy
- no new gateway startup or config errors appear in logs
