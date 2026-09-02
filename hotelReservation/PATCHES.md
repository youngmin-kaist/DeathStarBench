# hotelReservation benchmark patches

This branch (`hotelres-bench-patches`) carries the patches applied while
characterizing hotelReservation throughput on a single-node bare-metal
Kubernetes cluster (16 cores, kubeadm + Cilium) across service-mesh
configurations: no mesh, Istio sidecar, Istio ambient L4 (ztunnel), and
ambient L7 (ztunnel + waypoint). Load generator: the bundled wrk2.

Patches 1–3 are general correctness fixes that stand on their own; patch 4
changes service-discovery behavior specifically so ambient waypoints can
intercept internal gRPC; patches 5–6 are benchmarking conveniences.

## 1. rate: cache-miss query fetched the entire collection

`services/rate/server.go` built its MongoDB query with an empty filter, so
every memcached miss:

- ran a full scan of `rate-db.inventory` instead of a point lookup,
- returned **every** hotel's rate plans (27 in the stock dataset) rather than
  the requested ones, and
- wrote those poisoned values back to memcached, so the cache stayed wrong
  permanently.

The fix filters by `hotelId`. Measured effect on the 16-core node: the
`/hotels` ceiling rose from **4,143 to 13,421 RPS (3.2×)**, and scaling out
rate/reservation replicas became effective at all (the full scans had made
MongoDB the serialization point). As of this branch the bug is still present
in upstream `master` and has no upstream issue or PR.

## 2. Graceful shutdown: deregister from consul on SIGTERM/SIGINT

Services register in consul at startup but never deregister: on pod
termination the process died without cleanup, and because registrations carry
no working health check, every replaced pod stayed in the catalog as a
"passing" endpoint forever. gRPC `round_robin` then spread load over dead
addresses — after seven `helm upgrade` rollouts we observed 52 consul entries
for `srv-reservation` against 2 live pods.

Every service entrypoint (`cmd/*/main.go`) now traps SIGTERM/SIGINT and calls
`srv.Shutdown()`, which was already wired to `Registry.Deregister` but never
triggered. Reported upstream as
[issue #367](https://github.com/delimitrou/DeathStarBench/issues/367);
handler approach from [Orqys/DeathStarBench PR #6](https://github.com/Orqys/DeathStarBench/pull/6).

Note: abnormal termination (SIGKILL, OOM kill, panic) still leaves a stale
entry — a real fix for that needs consul health checks/TTLs, which the
registration code does not implement.

## 3. Idempotent database seeding

`initializeDatabase()` in `cmd/*/db.go` ran a blind `InsertMany` of the seed
data on every process start, so each pod restart and each extra replica
duplicated the dataset. After a day of restarts we measured **10–11×**
duplication (e.g. `rate-db.inventory`: 297 documents for 27 distinct hotels),
inflating every cache-miss response and degrading throughput.
[Upstream PR #359](https://github.com/delimitrou/DeathStarBench/pull/359)
reports the same problem but fixes it with `db.Drop()` on start, which races
between concurrently starting replicas and wipes runtime state on every
crash-restart.

This branch instead creates a **unique index on the seed identity**
(`hotelId`, `id`, `username`, `reviewId`, … per collection) and inserts with
`ordered:false`, ignoring duplicate-key errors. Each process inserts only
after its own index creation succeeded, so concurrent replica starts cannot
race duplicates in, and runtime data is never dropped.
`reservation-db.reservation` also receives runtime bookings, so it gets no
unique index; its single seed row is upserted instead.

## 4. Helm: register gRPC services by Service DNS, mark ports as `grpc`

Two chart changes needed to put the internal gRPC hops behind an L7 proxy
(Istio ambient waypoint):

- `service-config.tpl` sets `GeoIP`/`ProfileIP`/`RateIP`/`RecommendIP`/
  `ReserveIP`/`SearchIP`/`UserIP` to the Kubernetes Service DNS name, so
  services register in consul under the Service VIP instead of their pod IP.
  Ambient waypoints only intercept VIP-bound traffic; consul-supplied pod IPs
  bypass them entirely (with the stock chart, "ambient L7" measures nothing).
- gRPC Service ports carry `appProtocol: grpc`, so proxies parse h2c instead
  of mis-detecting HTTP/1.1 (which returned protocol-error 500s).

**Behavior change**: client-side load balancing moves from gRPC round_robin
over per-pod consul entries to the Service VIP path. Intended for the ambient
experiments; not proposed for upstream.

## 5. wrk2: single-endpoint max-throughput scripts

`wrk2/scripts/hotel-reservation/{user,hotel,reservation}-only.lua` format one
request in `init()` and replay it, keeping per-request RNG and formatting cost
out of the load generator.

- `hotel-only.lua` defaults to a coordinate (`lat=37.8555, lon=-122.314`)
  whose geo result is a single hotel, so rate/reservation process exactly one
  id per request and memcached effectively always hits. Override via
  `HR_LAT`/`HR_LON`/`HR_INDATE`/`HR_OUTDATE` environment variables (this wrk2
  fork does not pass `-- args` through).
- `reservation-only.lua` books over capacity so the request returns early
  without a MongoDB write, keeping repeated runs stateless. Warm once with
  `number=0` first — only a successful booking writes the date key.

## 6. docker-compose: frontend port range

`5000-5003:5000` lets multiple frontend replicas publish ports for
load-balancing experiments without editing the compose file per replica.
