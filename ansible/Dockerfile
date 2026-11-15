# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# CI's stand-in for the NanoPi-NEO3, on the same Debian point release.
# Ansible's modules need Python on the target.
FROM debian:12.15@sha256:268fb24c39bca92d326dd83ea3abebe4a3f7751c804ffef23bb6d857dd343ff8
RUN apt-get update && apt-get install --yes --no-install-recommends python3
CMD ["sleep", "infinity"]
