# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# CI's stand-in for the NanoPi-NEO3: its Debian point release, plus what the
# box has that Ansible's modules and sudo need.
FROM debian:12.15@sha256:268fb24c39bca92d326dd83ea3abebe4a3f7751c804ffef23bb6d857dd343ff8
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    ca-certificates python3 python3-apt sudo systemd
CMD ["sleep", "infinity"]
