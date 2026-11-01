# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The push, SMS, and voice-call order is an IRM personal notification rule,
# set by hand in IRM's user settings. Managing it here needs an IRM API
# token on top of the stack service account.

data "grafana_oncall_user" "alunduil" {
  username = "alunduil"
}

resource "grafana_oncall_escalation_chain" "alunduil" {
  name = "alunduil"
}

resource "grafana_oncall_escalation" "notify_alunduil" {
  escalation_chain_id = grafana_oncall_escalation_chain.alunduil.id
  type                = "notify_persons"
  persons_to_notify   = [data.grafana_oncall_user.alunduil.id]
  position            = 0
}

resource "grafana_oncall_integration" "grafana_alerting" {
  name = "Grafana Alerting"
  type = "grafana_alerting"

  default_route {
    escalation_chain_id = grafana_oncall_escalation_chain.alunduil.id
  }
}

# Email goes out with every page so an alert still lands when IRM is down.
resource "grafana_contact_point" "alunduil" {
  name = "alunduil"

  oncall {
    url = grafana_oncall_integration.grafana_alerting.link
  }

  email {
    addresses = [data.grafana_oncall_user.alunduil.email]
  }
}

resource "grafana_notification_policy" "default" {
  contact_point = grafana_contact_point.alunduil.name
  group_by      = ["grafana_folder", "alertname"]
}
