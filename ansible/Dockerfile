# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# CI's stand-in for the NanoPi-NEO3: its Debian point release, plus what the
# box has that Ansible's modules and sudo need.
FROM debian:13.7@sha256:9c6e381421d0f48d1b8133e573f33c185ee16cbf505eda9c4a8a4791b25ea8a6
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    ca-certificates python3 python3-apt sudo systemd
CMD ["sleep", "infinity"]
