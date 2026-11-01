# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# alunduil's contact methods, and the order IRM tries them, are IRM user
# settings managed by hand.

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

resource "grafana_contact_point" "alunduil" {
  name = "alunduil"

  oncall {
    url = grafana_oncall_integration.grafana_alerting.link
  }
}

resource "grafana_notification_policy" "default" {
  contact_point = grafana_contact_point.alunduil.name
  group_by      = ["grafana_folder", "alertname"]
}
