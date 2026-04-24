# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

import {
  to = google_dns_managed_zone.alunduil_com
  id = "projects/alunduil/managedZones/alunduil-com"
}

resource "google_dns_managed_zone" "alunduil_com" {
  name        = "alunduil-com"
  dns_name    = "alunduil.com."
  description = "alunduil.com"

  dnssec_config {
    state         = "on"
    non_existence = "nsec3"

    default_key_specs {
      algorithm  = "rsasha256"
      key_length = 2048
      key_type   = "keySigning"
    }

    default_key_specs {
      algorithm  = "rsasha256"
      key_length = 1024
      key_type   = "zoneSigning"
    }
  }

  depends_on = [google_project_service.dns]
}

# NS and SOA records are managed automatically by Cloud DNS — do not import or manage them here.

import {
  to = google_dns_record_set.blog_cname
  id = "alunduil/alunduil-com/blog.alunduil.com./CNAME"
}

resource "google_dns_record_set" "blog_cname" {
  project      = "alunduil"
  name         = "blog.alunduil.com."
  managed_zone = google_dns_managed_zone.alunduil_com.name
  type         = "CNAME"
  ttl          = 86400
  rrdatas      = ["c.storage.googleapis.com."]
}

import {
  to = google_dns_record_set.d_blog_cname
  id = "alunduil/alunduil-com/d.blog.alunduil.com./CNAME"
}

resource "google_dns_record_set" "d_blog_cname" {
  project      = "alunduil"
  name         = "d.blog.alunduil.com."
  managed_zone = google_dns_managed_zone.alunduil_com.name
  type         = "CNAME"
  ttl          = 86400
  rrdatas      = ["c.storage.googleapis.com."]
}

import {
  to = google_dns_record_set.r_blog_cname
  id = "alunduil/alunduil-com/r.blog.alunduil.com./CNAME"
}

resource "google_dns_record_set" "r_blog_cname" {
  project      = "alunduil"
  name         = "r.blog.alunduil.com."
  managed_zone = google_dns_managed_zone.alunduil_com.name
  type         = "CNAME"
  ttl          = 86400
  rrdatas      = ["c.storage.googleapis.com."]
}

import {
  to = google_dns_record_set.groton_a
  id = "alunduil/alunduil-com/groton.alunduil.com./A"
}

resource "google_dns_record_set" "groton_a" {
  project      = "alunduil"
  name         = "groton.alunduil.com."
  managed_zone = google_dns_managed_zone.alunduil_com.name
  type         = "A"
  ttl          = 300
  rrdatas      = ["64.68.174.54"]
}

import {
  to = google_dns_record_set.home_cname
  id = "alunduil/alunduil-com/home.alunduil.com./CNAME"
}

resource "google_dns_record_set" "home_cname" {
  project      = "alunduil"
  name         = "home.alunduil.com."
  managed_zone = google_dns_managed_zone.alunduil_com.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["alunduil-home2.freemyip.com."]
}
