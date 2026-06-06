# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

workspace "alunduil personal-systems" "C4 model of every system alunduil runs personally — repos, cloud infra, workstation, MCP fleet, home systems." {

    model {

        # ----- People -----

        alunduil = person "alunduil" "Operates and edits personal infra; runs apply locally post-merge to main."

        # ----- The repo itself -----

        infra = softwareSystem "alunduil-infrastructure" {
            description "Terraform repo managing GCP, Cloudflare, and personal GitHub repos."
            tags "Internal"

            bootstrapLayer = container "terraform/bootstrap/" "Local-apply identity layer" "Terraform" {
                description "GCP project, WIF pool/provider, deployer SAs, Cloudflare deployer tokens. Applied locally by alunduil only."
            }
            alunduilLayer = container "terraform/alunduil/" "CI-applied environment layer" "Terraform" {
                description "GitHub repos, Cloudflare zone + records + settings, project APIs. Applied post-merge to main."
            }
            githubRepoModule = container "terraform/modules/github_repository/" "Reusable repo module" "Terraform"
            justfile = container "justfile" "Operator entrypoints (bootstrap, alunduil)" "just"
            actionsCI = container ".github/workflows/" "pre-commit + (future) plan/apply pipelines" "GitHub Actions"
            archDocs = container "docs/architecture/" "C4 model (this directory)" "Structurizr DSL + Mermaid"
            howtoDocs = container "docs/how-to/" "Operator how-tos" "Markdown"
        }

        # ----- External software systems with containers we manage -----

        github = softwareSystem "GitHub" {
            description "Source hosting, Actions runtime, App identity surface."
            tags "External"

            tfApp = container "Terraform GitHub App" "Mints installation tokens for integrations/github provider" "GitHub App"
            actionsRuntime = container "Actions runner pool" "Executes workflows; presents OIDC tokens" "GitHub-hosted runners"
            pagesEdge = container "GitHub Pages" "Hosts blog.alunduil.com via alunduil.github.io" "GitHub Pages"
            repoChezmoi = container "alunduil-chezmoi" "Workstation dotfiles + age-encrypted secrets source" "Git repo"
            repoInfra = container "alunduil-infrastructure" "This repo" "Git repo"
            repoBlog = container "blog.alunduil.com" "Personal blog source" "Git repo"
            repoGrafana = container "grafana" "Grafana work/fork" "Git repo"
            haskellRepos = container "Haskell libraries" "collection-json.hs, network-arbitrary, network-uri-json, siren-json.hs, murl" "Git repos"
            otherRepos = container "Other repos" "woodland-generators, zfs-replicate" "Git repos"
        }

        gcp = softwareSystem "GCP project (alunduil)" {
            description "Single GCP project — Terraform state + CI deployer identity."
            tags "External"

            stateBucket = container "alunduil-tfstate" "Holds bootstrap and alunduil state; shared bucket (#80 splits it)" "Cloud Storage"
            wifPool = container "WIF pool 'github'" "Workload Identity Federation; trusts token.actions.githubusercontent.com" "IAM"
            wifProvider = container "WIF provider 'github-provider'" "Gated by assertion.repository; maps assertion.ref for branch-scoped principals" "IAM"
            deployerRO = container "github-deployer-ro SA" "Plan-job identity; impersonable from any branch (repo-scoped)" "Service Account"
            deployerRW = container "github-deployer-rw SA" "Apply-job identity; impersonable only from refs/heads/main" "Service Account"
            secretCfRo = container "cloudflare-api-token-deployer-ro" "RO CF token value; per-secret accessor IAM (RO SA only)" "Secret Manager"
            secretCfRw = container "cloudflare-api-token-deployer-rw" "RW CF token value; per-secret accessor IAM (RW SA only)" "Secret Manager"
            auditConfigs = container "Audit log configs" "Data Access logs: storage (READ+WRITE), secretmanager (READ)" "google_project_iam_audit_config"
            projectApis = container "Project services" "IAM, STS, ResourceManager, ServiceUsage, SecretManager, Storage" "Enabled APIs"
        }

        cloudflare = softwareSystem "Cloudflare" "Authoritative DNS, zone settings (SSL strict, DNSSEC), and deployer API tokens for alunduil.com." {
            tags "External"
        }

        # ----- External actors / systems (no Level 2 from this repo) -----

        squarespace = softwareSystem "Squarespace registrar" "Holds the alunduil.com registration and DS records for DNSSEC." {
            tags "External"
        }
        tplinkDdns = softwareSystem "TP-Link DDNS" "alunduil.tplinkdns.com — tracks the home WAN address." {
            tags "External"
        }
        keybase = softwareSystem "Keybase" "Domain verification via _keybase.alunduil.com TXT." {
            tags "External"
        }
        bluesky = softwareSystem "Bluesky (AT Protocol)" "Handle verification via _atproto.alunduil.com TXT." {
            tags "External"
        }

        # ----- External systems with Level 2 owned by alunduil-chezmoi -----

        workstation = softwareSystem "alunduil workstation" "Local machine: chezmoi-managed dotfiles, Claude Code, MCP server hosting. Containers documented in alunduil-chezmoi (issue #202)." {
            tags "External"
        }
        mcpFleet = softwareSystem "MCP fleet" "MCP servers Claude Code talks to (Notion, Readwise, GitHub, Cloudflare, TrueNAS, UptimeRobot, context7). Containers documented in alunduil-chezmoi (issue #202)." {
            tags "External"
        }

        # ----- Home network (interview-discovered) -----

        homeNetwork = softwareSystem "Home network" {
            description "LAN behind home.alunduil.com; TP-Link Deco mesh, TrueNAS appliance, HAOS device."
            tags "External"

            # Containers grouped by the hardware they run on. Per C4: independently
            # installable apps and data stores are Containers; appliance hardware
            # itself would be a Deployment Node, not modeled here.

            group "TP-Link Deco mesh (3 nodes, 5G failover)" {
                decoFirmware = container "Deco firmware" "Edge routing, port-forwards 32400 to Plex, 5G failover from G.Network fibre" "TP-Link Deco"
            }

            group "TrueNAS appliance (iXsystems MINI-3.0-E, 192.168.68.63)" {
                plexApp = container "Plex" "Media server; externally exposed; monitored by UptimeRobot" "TrueNAS app"
                tailscaleSubnetRouter = container "Tailscale subnet router" "Routes 192.168.68.0/24 over Tailscale mesh" "TrueNAS app"
                netdataApp = container "Netdata" "Real-time system metrics" "TrueNAS app"
                alloyApp = container "Grafana Alloy" "Telemetry collection agent" "TrueNAS app"
                scrutinyApp = container "Scrutiny" "Disk S.M.A.R.T. monitoring" "TrueNAS app"
                smbMedia = container "SMB share: media" "Plex media library + general media" "SMB share"
                smbScans = container "SMB share: scans" "Scanned documents" "SMB share"
                smbTakeout = container "SMB share: takeout" "Google Takeout archives" "SMB share"
            }

            group "HAOS device (separate hardware)" {
                haCore = container "Home Assistant Core" "Home automation; heartbeats UptimeRobot" "Home Assistant"
                haTailscaleExit = container "Tailscale exit node (HAOS)" "Tailscale exit node" "Tailscale"
            }
        }

        # ----- Other systems on alunduil's personal landscape -----

        tailscale = softwareSystem "Tailscale" "Mesh VPN control plane; coordinates node membership and ACLs." {
            tags "External"
        }
        uptimerobot = softwareSystem "UptimeRobot" "External availability monitoring; HTTP probes + heartbeat receivers." {
            tags "External"
        }
        grotonExit = softwareSystem "Remote Tailscale exit (Groton, SD)" {
            description "NanoPi-NEO3 in Groton, SD; physically off-site."
            tags "External"

            group "NanoPi-NEO3 (Groton, SD)" {
                nanoPiTailscale = container "Tailscale exit node (NanoPi)" "Tailscale exit node; heartbeats UptimeRobot" "Tailscale"
            }
        }

        # ----- Relationships -----

        alunduil -> workstation "Operates"
        alunduil -> infra "Edits, opens PRs"
        workstation -> infra "Local apply via 'just alunduil' and 'just bootstrap'"
        workstation -> mcpFleet "Tool surface for Claude Code"

        infra -> github "Manages repos via integrations/github provider"
        infra -> gcp "Applies via Workload Identity Federation"
        infra -> cloudflare "Applies via API token from Secret Manager"

        # GitHub identity flow
        actionsCI -> actionsRuntime "Runs on"
        actionsRuntime -> wifProvider "Presents OIDC token (repo claim)"
        wifProvider -> deployerRO "Impersonate (plan jobs, any branch)"
        wifProvider -> deployerRW "Impersonate (apply jobs, refs/heads/main only)"
        deployerRO -> auditConfigs "Reads logged via DATA_READ on storage / secretmanager"
        deployerRW -> auditConfigs "Reads + writes logged via DATA_READ/WRITE on storage / secretmanager"
        deployerRO -> stateBucket "Read state"
        deployerRW -> stateBucket "Read+write state"
        deployerRO -> secretCfRo "Access value"
        deployerRW -> secretCfRw "Access value"
        actionsRuntime -> tfApp "Authenticates Terraform GH provider via installation token"
        tfApp -> repoChezmoi "Manages (install scope today = all repos; #82 narrows)"
        tfApp -> repoInfra "Manages"
        tfApp -> repoBlog "Manages"
        tfApp -> repoGrafana "Manages"
        tfApp -> haskellRepos "Manages"
        tfApp -> otherRepos "Manages"

        # DNS surface. Cloudflare's deployer-token and zone-setting detail
        # lives in the trust model; here it's the external box the zone's
        # records point at.
        repoBlog -> pagesEdge "Built and published to"
        cloudflare -> pagesEdge "blog.alunduil.com → alunduil.github.io"
        cloudflare -> tplinkDdns "home.alunduil.com → alunduil.tplinkdns.com"
        cloudflare -> keybase "_keybase TXT"
        cloudflare -> bluesky "_atproto TXT"
        cloudflare -> squarespace "DS records delivered to registrar"

        # Home network ingress: plex.alunduil.com → home.alunduil.com →
        # alunduil.tplinkdns.com → home WAN → Deco port-forward → Plex.
        tplinkDdns -> decoFirmware "Resolves to home WAN; ingress to Deco mesh"
        decoFirmware -> plexApp "Port-forward 32400"

        # Tailscale mesh participation.
        workstation -> tailscale "Tailscale client; required path when off-LAN"
        workstation -> homeNetwork "Direct LAN access when at home"
        tailscaleSubnetRouter -> tailscale "Subnet router for 192.168.68.0/24"
        haTailscaleExit -> tailscale "Tailscale exit node"
        nanoPiTailscale -> tailscale "Tailscale exit node"

        # UptimeRobot monitoring surface.
        uptimerobot -> plexApp "HTTP + HTTPS probes on home.alunduil.com:32400"
        haCore -> uptimerobot "Heartbeat push (home)"
        nanoPiTailscale -> uptimerobot "Heartbeat push (groton)"

        # ----- Deployment: physical topology -----
        # Appliances/devices are Deployment Nodes; the containers above are
        # placed onto the hardware that runs them. This is the home network's
        # physical graph — the C4 axis that maps to where things actually live,
        # kept separate from the logical "what talks to what" container views.

        deploymentEnvironment "Home network" {
            deploymentNode "TP-Link Deco mesh" "3 nodes; G.Network fibre with 5G failover" "TP-Link Deco" {
                containerInstance decoFirmware
            }
            deploymentNode "TrueNAS appliance" "iXsystems MINI-3.0-E; 192.168.68.63" "TrueNAS SCALE" {
                containerInstance plexApp
                containerInstance tailscaleSubnetRouter
                containerInstance netdataApp
                containerInstance alloyApp
                containerInstance scrutinyApp
                containerInstance smbMedia
                containerInstance smbScans
                containerInstance smbTakeout
            }
            deploymentNode "HAOS device" "Dedicated Home Assistant hardware" "Home Assistant OS" {
                containerInstance haCore
                containerInstance haTailscaleExit
            }
            deploymentNode "NanoPi-NEO3" "Off-site; Groton, SD" "Armbian" {
                containerInstance nanoPiTailscale
            }
        }
    }

    views {

        systemLandscape "System-Landscape" {
            include *
            autolayout lr
            description "Level 1 — every system alunduil operates personally."
        }

        container infra "Container-Infra" {
            include *
            autolayout lr
            description "Level 2 — alunduil-infrastructure containers."
        }

        container gcp "Container-GCP" {
            include *
            autolayout lr
            description "Level 2 — GCP project containers."
        }

        container github "Container-GitHub" {
            include *
            autolayout lr
            description "Level 2 — GitHub containers (App, Actions, managed repos)."
        }

        container homeNetwork "Container-HomeNetwork" {
            include *
            autolayout lr
            description "Level 2 — home network containers (Deco firmware, TrueNAS apps + shares, HAOS apps)."
        }

        deployment * "Home network" "Deployment-HomeNetwork" {
            include *
            autolayout lr
            description "Physical topology — devices/appliances and the containers they run."
        }

        styles {
            element "Person" {
                shape person
                background #08427b
                color #ffffff
            }
            element "Internal" {
                background #1168bd
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Stub" {
                background #cccccc
                color #555555
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
        }
    }
}
