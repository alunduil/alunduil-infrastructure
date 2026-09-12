<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Build the NanoPi-NEO3 recovery image with Armbian's build framework

- Status: Accepted
- Date: 2026-09-12

## Context and Problem Statement

A NanoPi-NEO3 in the American Midwest runs one service: a Tailscale
exit node that puts traffic on a US address. It's administered from
London. An UptimeRobot heartbeat watches it from off the box, because
a dead box can't report its own failure.

Recovery today means flashing a stock image, restoring package
selections and `/home` from the hourly `rclone` backup in Google
Drive, then merging `/etc` by hand over SSH. The merge is the fragile
part. The backed-up `fstab` names the old card's root UUID, and
restoring it leaves a box that can't find its root — no console, no
way in, and a second trip to arrange for hands on another continent.
DHCP was chosen deliberately so that no network configuration has to
survive the same merge.

The plan has never been run. Rehearsing it means breaking the exit
node nobody can reach, so the distance that makes the plan worth
writing is the distance that keeps it untested.

What has to be decided is where the box's configuration comes from
when a card is flashed, and what applies it after the box boots.

### Recovery framing

- **The hands on site are willing and not technical.** They can swap a
  card, apply power, forward a port on the router, and — given lay
  instructions and equipment bought and delivered locally — write an
  image to a card. Posting a card from London isn't wanted.
- **The board hides its own failures.** `config/boards/nanopineo3.csc`
  sets `HAS_VIDEO_OUTPUT="no"` and puts the console on `ttyS2`, and
  FriendlyELEC's specification lists one microSD slot and no eMMC or
  SPI flash. A board that fails to boot looks exactly like a dead card
  unless someone on site attaches a USB-TTL adapter.
- **Break-glass SSH is acceptable as a step, not as the mechanism.**
  Reaching the box over a temporary port forward to finish recovery is
  fine. Depending on that session to carry the configuration is what
  this decision exists to end.
- **Everything published from this repo is public.**

### Requirements

Three constraints decide the outcome. An option failing any one is
out regardless of how it scores elsewhere.

- **Lay hands can flash it.** A consumer imaging tool on Windows or
  macOS writes the artifact to a card, and the card boots with no
  further edits. The NEO3's image has a single ext4 partition, so any
  approach needing a file edited on the card before first boot
  requires a Linux machine on site and fails here.
- **SSH on first boot, on a key already held.** A freshly flashed card
  must trust the operator's key before it has any network identity.
- **No extractable secret in the artifact.** A credential inside a
  public release is a published credential.

## Decision Drivers

Where options both clear the requirements, these decide between them:

- Machinery budget. This box is an exit node for geolocation and
  nothing else; it earns a workflow file, not a distribution to
  maintain.
- Configured wherever configuration is free. Anything settable without
  a secret — Tailscale, Grafana Alloy, unattended upgrades, hostname,
  DHCP — should already be settled when the card boots.
- Testable without an outage.
- One description of the box, applied both at build time and
  afterwards, so the two can't drift.
- A normal patching path after recovery.
- Board reality. `nanopineo3` carries `BOARD_MAINTAINER=""`, sits in
  Armbian's community tier, and has exactly one published artifact —
  a weekly `-trunk` build of Debian 13. No option here changes that,
  so no option can be credited for it.

## Considered Options

- **Flash a stock image, configure over break-glass SSH.** No build at
  all; configuration lives as a script in this repo and runs after the
  operator gets in. Fails the second requirement: a stock image trusts
  no key of ours, so the way in is the default root password that
  ships in every copy of that image, over a port forward open to the
  internet. Armbian's first-login flow would change that password, but
  it gates on an interactive terminal, and this board's console is a
  serial line nobody on site can reach.
- **Armbian's build framework with a committed `userpatches/`
  overlay.** Their composite action checks out the framework, copies
  this repo's `userpatches/` over it, builds, and publishes the image.
  Clears all three requirements. Costs a rolling Debian userspace that
  the framework can't pin.
- **Customize a stock image in CI.** Loop-mount Armbian's published
  image, enter it with `qemu-user-static`, write files, repack —
  by hand, or through Packer's ARM builder or CustomPiOS. Clears the
  requirements and reuses a boot chain rather than building one, but
  loop-device partition nodes have been broken on GitHub-hosted
  runners since December 2024, so the approach whose appeal was "a
  hundred lines and no framework" stops being that.
- **`debos`.** A declarative recipe builder whose `raw` action can
  write boot blobs at the byte offsets RK3328 needs. Clears the
  requirements. Costs supplying RK3328 u-boot, and it builds inside a
  virtual machine that wants KVM, which GitHub-hosted runners don't
  expose.
- **NixOS `sd-image-aarch64`.** The strongest configuration story
  here: `authorizedKeys`, `services.tailscale`, `services.alloy` and
  `system.autoUpgrade` are declarations, and the closure is pinned in
  a way no Debian option matches. Costs board bring-up that exists
  nowhere upstream — no entry in `nixos-hardware`, no NEO3 device tree
  in mainline Linux, and no NEO3 u-boot `defconfig`. The device tree
  lives only as a patch in Armbian's tree.
- **Buildroot or Yocto.** Both can place u-boot correctly for this
  SoC, and neither carries a NEO3 configuration. Both give up Debian
  packaging, so a security update becomes a rebuild and a fresh card,
  flashed by the non-technical person on another continent.
- **Ubuntu Core.** Immutable and snap-managed, but there's no RK3328
  support. Reaching it means a kernel snap, a gadget snap, a signed
  model assertion and a registered brand account.
- **DietPi.** Its `dietpi.txt` gives the whole first-boot story on a
  stock image with no build at all, and there's a current NEO3 image.
  The automation file sits on that single ext4 partition, so editing
  it before flashing needs a Linux machine on site.
- **Clone the running card with `dd`.** The cheapest-looking baseline
  and the worst artifact. Imaging a live, mounted ext4 root captures a
  dirty journal; the copy carries the SSH host keys and
  `/var/lib/tailscale` into offsite storage in the clear; and the
  cloned identity collides with the original if it ever returns.
  Nothing reviews it, nothing tests it, and it fails the third
  requirement outright.

## Decision Outcome

Chosen option: **Armbian's build framework, driven by their composite
action, with `userpatches/` committed to this repo and the image
published as a public GitHub Release.**

The second requirement eliminates the options that flash something
Armbian or DietPi published, because a stock image can't be made to
trust a key before it boots. Among the options that produce an image,
the framework asks for the least: the action copies this repo's
overlay into a checkout it manages and publishes the result, so what
is owned here is an overlay and a workflow rather than a boot chain.
Every option that builds a root filesystem from scratch — `debos`,
Buildroot, NixOS — requires supplying RK3328 u-boot, and NixOS also
requires carrying a device tree that only Armbian has. Every option
that edits a published image has to work around GitHub's loop devices.

NixOS is rejected on budget rather than on merit. Its configuration
and pinning story is better than the chosen option's, and the
remaining work is board bring-up on hardware whose only upstream
support is the community-tier Armbian entry. Paying for that
bring-up on a box that exists to provide a US address isn't a trade
this decision makes.

### What the image carries

Baked in: the operator's public key in root's `authorized_keys`,
password authentication disabled, the first-login flag cleared so it
can't gate SSH, the hostname, DHCP, and Tailscale, Grafana Alloy and
unattended upgrades installed and enabled.

Deliberately absent: any Tailscale auth key or OAuth client secret,
any Alloy credential, any private key. The artifact is public, so it
holds public key material only. A card that can't authenticate itself
to the tailnet is the point — the two credential-bearing steps belong
to the operator's SSH session, and a stolen or mislaid card grants
nothing.

This also settles the direction of #262: the Tailscale identity
doesn't travel on the card. Auth keys expire
within 90 days and there's no non-expiring variant, so a spare card in
a drawer would carry a credential that rots long before it's needed.

### Configuring the box after boot

One idempotent shell script in `scripts/` is the single description of
the box. `customize-image.sh` runs it inside the `chroot` at build
time; the operator runs it over SSH during recovery and for ordinary
changes afterwards. Applying the same script at both moments is what
keeps the image and the running box from drifting into two different
answers.

A script rather than Ansible because the box is roughly ten facts and
this repo already keeps its shell helpers in `scripts/` under bats
coverage. Escalate to Ansible when the fact count outgrows what a
reader can hold, or when drift detection is worth a control machine
for one host.

### The recovery procedure

1. On-site hands swap the spare card taped to the unit and power it on.
2. They forward a port on the router.
3. The operator connects over SSH on the baked-in key and runs the
   configuration script, supplying the Tailscale and Alloy
   credentials.
4. The port forward comes down; the box is on the tailnet.
5. A fresh spare is flashed and taped back to the unit.

Step 5 is also the rehearsal. Refreshing the spare exercises the whole
pipeline — build, publish, flash, boot — while the live exit node
keeps running, which is what the current plan can't do. A spare that
fails to boot costs a swap back, not an outage.

### Risks accepted

- **The board is unmaintained.** Armbian states that community-tier
  images are untested and that it will neither respond to problems nor
  apply fixes for them. This is equally true of the image the box runs
  now.
- **The Debian userspace can't be pinned** by the framework, which
  builds against live archives. Kernel, u-boot and firmware pin by tag
  or commit, and the framework itself pins by action ref.
- **The SD card is the only boot device.** No eMMC, no SPI, no USB
  boot on this SoC. The single point of failure survives this
  decision; the spare card is the mitigation.
- **A cold build compiles a kernel**, which takes over an hour on
  comparable Rockchip boards. Warm builds pull a cached kernel package
  and finish in roughly a quarter of an hour. Neither figure has been
  measured for this board.

### Consequences

Good:

- Recovery stops depending on a hand-merged `/etc`. The trap that
  motivated the whole plan — restoring an `fstab` that names a UUID
  the new card doesn't have — can't occur, because nothing is restored
  over the image.
- The configuration becomes reviewable. What the box is gets read in a
  diff rather than reconstructed from a backup of what it was.
- The recovery path becomes testable without risking the exit node,
  through the spare-card refresh above.
- A lost or stolen card grants nothing, and no credential in the
  pipeline expires while waiting to be used.

Bad / accepted:

- This repo takes on an image build and a published artifact for one
  board, and the build tracks a rolling Debian userspace.
- Recovery still needs one interactive SSH session and a port forward.
  Removing it would mean putting a bearer credential on a card kept in
  a home on another continent.
- The image and the running box can still diverge between refreshes.
  The script is idempotent, not enforcing; nothing detects a change
  made by hand and never committed.

Neutral:

- The hourly `rclone` sync of `/etc` stops being load-bearing, since
  configuration recovery moves into the image. What that means for the
  backup is a separate question.
- Whether other hosts adopt the same build-and-script pattern isn't
  settled here. This record covers one board.

## More Information

Build work is tracked in #261. The Tailscale identity question is #262,
and the Alloy outage that stopped this box shipping telemetry is #473 —
independent of this decision, since the image installs Alloy without
inheriting its broken state.

The recovery plan this replaces is described in
<https://blog.alunduil.com/posts/how-i-recover>.
