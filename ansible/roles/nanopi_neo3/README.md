<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# nanopi_neo3

Configures the NanoPi-NEO3 exit node: Tailscale, Grafana Alloy, unattended
upgrades with mail through Gmail, and the UptimeRobot heartbeat. It removes the
`rclone` backup ADR 0007 retires, and `rsyslog`, whose text files duplicate
the journal Alloy ships. Run it with `just nanopi-neo3`.

## Not carried forward

The box still runs FriendlyElec's Debian image. The role leaves these parts of
it in place, and the recovery image (#261) doesn't reproduce them:

- `lcd2usb`, which drives a USB character display.
- `rc-local`, which creates SSH host keys on first boot and opens GPIO access.
- `friendlyelec_firstuse` and `leds`, the vendor's first-boot and LED services.
- `bluetooth` and `wpa_supplicant`. The box connects over Ethernet.
- `NetworkManager`. ADR 0006 bakes DHCP into the image.
- `ntpsec` and `anacron`. The image's defaults cover time and periodic jobs.
- The Debian mirror at `mirrors.cloud.tencent.com` in `/etc/apt/sources.list`.
- `/home/pi`, left by the image's removed default user.
