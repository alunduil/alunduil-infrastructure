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
each cheap.** That is what the platform must make frictionless.

## Decision Drivers

- Operational burden and day-2 upgrade path.
- Declarative / GitOps fit — the repo already treats git as the source
  of truth (Terraform, Grafana Git Sync).
- Per-service overhead as the service count grows.
- Hardware needs against what exists today (an 8 GB, 2-core TrueNAS
  Mini 3.0-E) versus new nodes.
- Backup and recovery.
- Networking / ingress + DNS, integrating with Cloudflare.
- Secrets management.
- Blast radius — keeping an experimental long tail from taking down the
  storage + Plex appliance.

## Considered Options

- Proxmox VE (VMs + LXC)
- Small Kubernetes — Talos Linux (also k3s / k0s)

## Decision Outcome

Chosen option: **small Kubernetes on Talos Linux**, because the workload
is a many-small-churning-services long tail, and Kubernetes' per-service
unit (a pod plus a few lines of declarative YAML in git) is far cheaper
to add and remove than a hand-built VM or LXC per service. Talos
specifically neutralizes the usual reason to reject small Kubernetes —
its day-2 tax — by being an immutable, API-managed OS with atomic,
image-based upgrades and no host to hand-patch.

k3s and k0s are reasonable small-Kubernetes distributions, but they
leave a general-purpose Linux host to own and patch per node. Talos
removes that surface, which is the decisive advantage at a homelab's
staffing level (one person, part-time).

Proxmox VE is rejected: it optimizes for fewer, heavier, longer-lived
VMs and has no native declarative service loop, so every service stays
a hand-rolled unit — exactly the per-service drift this platform is
meant to end.

### Migration sketch (reversible; "start here, revisit at N")

The platform is stood up in phases so the substrate can be swapped
under the cluster without a rebuild:

1. **RAM upgrade.** Double the TrueNAS Mini 3.0-E from 8 GB to 16 GB.
   This is worth doing on its own — the box runs at ~0.6 GB free and
   hits system-wide OOM today — and it makes room for a VM. (Confirm the
   board accepts a 16 GB ECC SODIMM before ordering.)
2. **Single node.** Run one Talos node as a VM on the upgraded TrueNAS
   box. Learn the platform, wire GitOps. A single-node cluster has
   stable quorum (1-of-1); it is simply not redundant, which is
   acceptable for bootstrap.
3. **Three nodes on dedicated hardware.** When hardware is acquired, go
   straight from one node to three — deliberately skipping the fragile
   two-node etcd state, which loses quorum if either node dies. This may
   be two VMs plus one metal node, or three matched metal nodes bought
   together to complete the move in one step.
4. **End state.** Three dedicated nodes beside TrueNAS; the VMs retired.
   Quorum and blast radius fully decoupled from the storage appliance.

The seam: the platform lives on TrueNAS transitionally and converges on
dedicated hardware beside it. The multi-node cluster is the vehicle that
lets nodes be drained and replaced with metal without downtime.

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
  config) than Proxmox's one-stop vzdump / Proxmox Backup Server.
- **During the VM phase specifically:** the 2-core Atom C3338 is the
  throughput ceiling, and etcd contends with Plex transcode spikes — a
  modest learning cluster, not a workhorse; quorum and blast radius stay
  coupled to the NAS until nodes move to metal.

Neutral:

- Home infrastructure remains outside Terraform for now. Whether to
  bring the cluster (Talos machine config, GitOps bootstrap) under
  Terraform is a separate future decision, not settled here.

## More Information

Follow-up build work, to be filed as separate issues rather than done
here (this ADR is the decision, not the apply):

- RAM upgrade of the TrueNAS Mini 3.0-E to 16 GB — independent; also
  resolves the current OOM. Unblocks the bootstrap.
- Bootstrap a single-node Talos VM and wire GitOps — blocked by the RAM
  upgrade.
- Expand to a three-node cluster on dedicated hardware — blocked by
  hardware acquisition.

Relates to the home surface characterized in the C4 model (#84).
