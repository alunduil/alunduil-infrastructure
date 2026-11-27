# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

locals {
  snapshot_tasks = {
    hourly = {
      id             = "4"
      naming_schema  = "auto-%Y%m%d.%H%M-2d"
      lifetime_value = 2
      lifetime_unit  = "DAY"
      schedule       = { minute = "0", hour = "*", dom = "*", month = "*", dow = "*" }
    }
    daily = {
      id             = "3"
      naming_schema  = "auto-%Y%m%d.%H%M-2w"
      lifetime_value = 2
      lifetime_unit  = "WEEK"
      schedule       = { minute = "0", hour = "0", dom = "*", month = "*", dow = "*" }
    }
    weekly = {
      id             = "2"
      naming_schema  = "auto-%Y%m%d.%H%M-2m"
      lifetime_value = 2
      lifetime_unit  = "MONTH"
      schedule       = { minute = "0", hour = "0", dom = "*", month = "*", dow = "sun" }
    }
    monthly = {
      id             = "1"
      naming_schema  = "auto-%Y%m%d.%H%M-2y"
      lifetime_value = 2
      lifetime_unit  = "YEAR"
      schedule       = { minute = "0", hour = "0", dom = "1", month = "*", dow = "*" }
    }
  }
}

# Every task snapshots the whole pool, so each one leaves out the same
# datasets.
resource "truenas_periodic_snapshot_task" "pool" {
  for_each = local.snapshot_tasks

  dataset        = local.pool
  recursive      = true
  allow_empty    = true
  enabled        = true
  naming_schema  = each.value.naming_schema
  lifetime_value = each.value.lifetime_value
  lifetime_unit  = each.value.lifetime_unit

  exclude = [
    "${local.pool}/takeout",
    "${local.pool}/tlazolteotl",
    truenas_dataset.plex_logs.name,
  ]

  schedule = merge(each.value.schedule, { begin = "00:00", end = "23:59" })
}

import {
  for_each = local.snapshot_tasks

  to = truenas_periodic_snapshot_task.pool[each.key]
  id = each.value.id
}
