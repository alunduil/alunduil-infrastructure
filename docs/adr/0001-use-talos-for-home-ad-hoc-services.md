<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Use Talos Linux for the home ad-hoc-services platform

- Status: Proposed
- Date: 2026-07-18

## Context and Problem Statement

"I want to run X at home" currently means shoehorning X into TrueNAS
apps or hand-standing a one-off VM. There is no deliberate platform for
the long tail of small, experimental, comes-and-goes services, so each
new service is a fresh ad-hoc decision and the drift accumulates.

We need one platform, chosen on purpose, that turns "where does this new
thing go?" into a settled, paved-road answer. The two candidates are
**Proxmox VE** (a VM/LXC hypervisor) and a **small Kubernetes cluster**
(k3s / k0s / Talos). Which one, and why?

### Workload framing

The decision hangs on an honest read of the workload:

- **Count and lifecycle.** A long tail — a handful today, growing —
  mostly small and experimental (comes and goes), with a few that
  persist. The unit of change is "add/remove a small service," often.
- **Resource shape.** Each service is small: typically a single
  container, low CPU and RAM. The aggregate matters more than any one
  service.
- **State.** Mostly stateless or lightly stateful. Durable data belongs
  on TrueNAS (the existing storage appliance) over NFS/iSCSI, not
  trapped inside the platform.
- **Exposure.** Mostly LAN-only; some behind `home.alunduil.com`. DNS
  for `alunduil.com` is on Cloudflare, not Cloud DNS, so ingress
  integrates with Cloudflare (tunnel / DNS), per the repo gotchas.
- **Relationship to existing infra.** TrueNAS stays the storage + Plex
  appliance. The platform runs *beside* it (transitionally *on* it as a
  VM — see the migration sketch), consuming TrueNAS for persistent
  volumes rather than replacing it.

The shape that matters most: **many small services, churning often,
each cheap.** That's what the platform must make frictionless.

### Requirements

Three constraints decide the outcome. An option failing any one of them
is out regardless of how it scores elsewhere:

- **Multi-node with automatic placement and rescheduling.** A failed
  node moves its services without hands on a keyboard.
- **Storage as shares from TrueNAS.** NFS and iSCSI from the existing
  appliance, not a storage layer living inside the platform.
- **Start on one node and scale out.** The first node has to grow into
  the cluster rather than be thrown away.

## Decision Drivers

Where two options both clear the requirements, these decide between
them:

- Containers as the unit of deployment. Every service running at home
  today is one, and nothing in the footprint is appliance-shaped. VM
  hosting stays on TrueNAS, where phase 1's own node runs.
- Operational burden and day-2 upgrade path.
- Declarative / GitOps fit — the repo already treats git as the source
  of truth (Terraform, Grafana Git Sync).
- Per-service overhead as the service count grows.
- Hardware needs against what exists today (a 16 GB, 2-core TrueNAS
  Mini 3.0-E) versus new nodes.
- Backup and recovery.
- Networking / ingress + DNS, integrating with Cloudflare.
- Secrets management.
- Blast radius — keeping an experimental long tail from taking down the
  storage + Plex appliance.

## Considered Options

- **TrueNAS apps** (the status quo) — Docker apps on the existing
  appliance. Free and already running, but there's no declarative loop,
  the catalog is thin, and it fails multi-node outright.
- **Docker Compose, or Podman with quadlets** — compose files in git on
  a plain Linux host. The lowest operational floor of anything here,
  and genuinely declarative for a handful of services. Fails automatic
  rescheduling: a dead host is a hands-on recovery.
- **Incus / LXD** — the previous plan for this platform, and the only
  option here that runs system containers and VMs equally well.
  Clears the requirements. Loses on the declarative loop: its GitOps
  and CSI ecosystems are thin next to Kubernetes, so the services
  inside the instances stay hand-managed even when the instances
  themselves are declared.
- **Proxmox VE** — VMs and LXC, with a mature single-node story,
  snapshots, and backups. Clears the requirements, but optimizes for
  fewer, heavier, longer-lived instances and has no native declarative
  service loop, so every service stays a hand-rolled unit — the
  per-service drift this platform exists to end.
- **Nomad** — a single-binary orchestrator with real multi-node
  scheduling, and HCL jobs in a repo already fluent in HCL. Clears the
  requirements. Loses on storage: its CSI ecosystem is thinner, with
  nothing equivalent to democratic-csi driving the TrueNAS API, and
  the 2023 move to a BUSL license adds a durability question.
- **Small Kubernetes** — k3s, k0s, or Talos Linux. Clears the
  requirements, with the deepest storage and ingress ecosystem of the
  options here. Costs the highest conceptual floor.

## Decision Outcome

Chosen option: **small Kubernetes on Talos Linux**. The requirements
eliminate the two lightest options, TrueNAS apps and Compose, on
automatic rescheduling. Among the four that remain, the declarative
service loop decides it: Incus and Proxmox manage instances well but
leave the services inside them hand-managed, and Nomad schedules well
but has nothing equivalent to democratic-csi driving the TrueNAS API.
Kubernetes' per-service unit — a pod and a few lines of YAML in git —
is what makes a churning long tail cheap to add to and cheap to retire
from, and its storage and ingress ecosystems are the deepest here.

Within that family, k3s and k0s are reasonable distributions, but they
leave a general-purpose Linux host to own and patch per node. Talos
removes that surface — immutable, API-managed, atomic image-based
upgrades, no host to hand-patch — which neutralizes the day-2 tax that
is the usual reason to reject small Kubernetes at a homelab's staffing
level of one person, part-time.

### Migration sketch (reversible)

The platform is stood up in phases so the substrate can be swapped
under the cluster without a rebuild:

1. **Single node.** Run one Talos node as a VM on the TrueNAS box,
   whose 16 GB leaves room for it. Learn the platform, wire GitOps. A
   single-node cluster has stable quorum (1-of-1); it's not redundant,
   which is acceptable for bootstrap.
2. **Three nodes on dedicated hardware.** When hardware is acquired, go
   straight from one node to three — deliberately skipping the fragile
   two-node etcd state, which loses quorum if either node dies. This may
   be two VMs plus one metal node, or three matched metal nodes bought
   together to complete the move in one step. Nodes drain and are
   replaced with metal while services keep running.
3. **End state.** Three dedicated nodes beside TrueNAS; the VMs retired.
   Quorum and blast radius fully decoupled from the storage appliance.

### Phase 1 risks

These bind only while the cluster runs as a VM on TrueNAS, and retire
when phase 2 lands:

- **Capacity.** The 2-core Atom C3338 is the throughput ceiling — it
  already sits near a load average of 1 — and free memory runs
  1–1.5 GB once the ZFS cache has warmed, so a node large enough to be
  useful means capping that cache and trading NAS read performance for
  the cluster. Quorum and blast radius stay coupled to the NAS until
  nodes move to metal.
- **etcd on the NAS pool**, the sharpest of the three. etcd commits
  every write with `fsync`, and the pool is raidz2 with no separate
  log device, so those commits queue behind Plex and share traffic on
  the same vdevs. Slow commits surface as leader elections and an
  unresponsive API server rather than as a disk alert. Watch
  `etcd_disk_wal_fsync_duration_seconds` from the start; sustained
  trouble there argues for moving to metal sooner.
- **QuickSync can't be tested here.** The Atom C3338 has no integrated
  GPU, so the i915 extension, the Intel device plugin, and the Plex
  transcode path stay untested until dedicated hardware arrives.

### Consequences

Good:

- Adding or retiring a service is a git commit against declarative
  manifests, not a hand-built VM — the paved road the platform exists
  to provide, and a fit with the repo's existing GitOps posture.
- Per-service overhead stays low as the count grows; the control-plane
  cost is paid once and amortized across the long tail.
- Talos' atomic, image-based upgrades and absence of a hand-patched host
  OS give the best day-2 story of the options considered.
- The same declarative config runs the cluster as VMs now and as metal
  later, enabling the reversible migration above.
- Ingress (Gateway API / an ingress controller + cert-manager) and
  Cloudflare integration are first-class, matching the DNS reality.

Bad / accepted:

- A higher conceptual floor than Proxmox's VM-and-web-UI model; running
  this means owning Kubernetes concepts.
- etcd is a shared failure domain. Real redundancy arrives only at the
  three-node, separate-hardware phase; earlier phases trade redundancy
  for a cheap start.
- Backup is more assembly (etcd snapshots + volume snapshots + git for
  config) than Proxmox's one-stop `vzdump` / Proxmox Backup Server.

Neutral:

- Home infrastructure remains outside Terraform for now. Whether to
  bring the cluster (Talos machine config, GitOps bootstrap) under
  Terraform is a separate future decision, not settled here.

## More Information

Build work is tracked in #241 and its sub-issues.

Relates to the home surface characterized in the C4 model (#84).
