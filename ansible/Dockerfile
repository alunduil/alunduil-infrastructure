# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# CI's stand-in for the NanoPi-NEO3: its Debian point release, plus what the
# box has that Ansible's modules and sudo need.
FROM debian:12.15@sha256:1d04200c2ece1d4d75a2a6f8e11ebce7d86a2ae28b34bb2c9cbb3ee9f4953e75
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    ca-certificates python3 python3-apt sudo systemd
CMD ["sleep", "infinity"]
