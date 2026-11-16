<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure the NanoPi-NEO3

`just nanopi-neo3` runs the Ansible playbook against the NanoPi-NEO3 over the
tailnet. No workflow runs it, so a change under `ansible/` takes effect only
when you run the recipe. It reads two credentials from Secret Manager: the
Alloy push token (C-37), which bootstrap creates, and a Gmail app password
(C-38), which you create and store. This guide doesn't cover reaching a box
that has left the tailnet.

## Prerequisites

- `gcloud` authenticated with read access to the
  `grafana-alloy-push-token-nanopi-neo3` and `gmail-app-password-nanopi-neo3`
  secrets, and to `bootstrap-outputs.json` in the state bucket.
- `just bootstrap` applied, so both secrets exist.
- A current Tailscale SSH login. Run `tailscale ssh nanopi-neo3 true` and
  complete the browser login it asks for.

## Create the app password

Unattended upgrades mail their reports through Gmail, which accepts only an
app password from the box.

1. Sign in to the Google account the reports go to, and open
   <https://myaccount.google.com/apppasswords>.
2. Name it `nanopi-neo3` and select **Create**.
3. Copy the password from the dialog that follows.

## Store the app password

Run `just bootstrap` and paste the password at its prompt. To store or rotate
it without the rest of the bootstrap:

```sh
GMAIL_APP_PASSWORD=<password> scripts/configure-nanopi-neo3-secrets.sh
```

After the next `just nanopi-neo3` succeeds, delete the old password at
<https://myaccount.google.com/apppasswords>.

## Preview the changes

```sh
just nanopi-neo3 --check --diff
```

A run reporting `changed=0` means the box matches the playbook. Any other
count is drift: a hand edit on the box, or a change under `ansible/` not yet
applied.

## Apply the configuration

```sh
just nanopi-neo3
```

If the run asks for the heartbeat URL, copy it from the monitor's page in
UptimeRobot.
