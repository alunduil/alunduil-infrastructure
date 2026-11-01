# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Every firing Grafana alert reaches alunduil through IRM, which pages by
# mobile push, SMS, and voice call. The order and delays between those
# channels are IRM personal notification rules, set by hand in IRM's user
# settings: managing them here would need a separate IRM API token, which
# the stack service account can't stand in for.

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

# A contact point notifies through every integration it holds at once, so
# the email goes out alongside the IRM page rather than after it fails. It
# still arrives when IRM is down.
resource "grafana_contact_point" "alunduil" {
  name = "alunduil"

  oncall {
    url = grafana_oncall_integration.grafana_alerting.link
  }

  email {
    addresses = ["alunduil@gmail.com"]
  }
}

resource "grafana_notification_policy" "default" {
  contact_point = grafana_contact_point.alunduil.name
  group_by      = ["grafana_folder", "alertname"]
}
