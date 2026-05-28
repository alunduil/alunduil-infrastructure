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

        cloudflare = softwareSystem "Cloudflare" {
            description "DNS and zone settings for alunduil.com."
            tags "External"

            zone = container "alunduil.com zone" "Authoritative NS = brenna/vick.ns.cloudflare.com; DNSSEC active" "Zone"
            zoneSettings = container "Zone settings" "SSL=strict, min-TLS=1.2, always-use-https=on" "Settings"
            dnsRecords = container "DNS records" "blog/home/plex CNAMEs; _keybase / _atproto TXT" "DNS"
            cfTokenRO = container "deployer-ro token" "Zone+DNS+Settings Read on alunduil.com" "API token"
            cfTokenRW = container "deployer-rw token" "Zone Read, DNS+Settings Write on alunduil.com" "API token"
            cfMasterToken = container "master token" "Operator-only; minted before bootstrap apply, revoked after" "API token (ephemeral)"
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

        # ----- Stub: Level 2 pending interview-driven discovery in this repo -----

        homeNetwork = softwareSystem "Home network" "Behind home.alunduil.com: TrueNAS, Plex, UPS, switch/router/AP. Containers TBD." {
            tags "External" "Stub"
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

        # Cloudflare token flow
        cfMasterToken -> cfTokenRO "Mints once, then revoked"
        cfMasterToken -> cfTokenRW "Mints once, then revoked"
        cfTokenRO -> secretCfRo "Value stored in"
        cfTokenRW -> secretCfRw "Value stored in"

        # DNS surface
        repoBlog -> pagesEdge "Built and published to"
        dnsRecords -> pagesEdge "blog.alunduil.com → alunduil.github.io"
        dnsRecords -> tplinkDdns "home.alunduil.com → alunduil.tplinkdns.com"
        dnsRecords -> keybase "_keybase TXT"
        dnsRecords -> bluesky "_atproto TXT"
        tplinkDdns -> homeNetwork "Resolves to home WAN"
        zone -> squarespace "DS records delivered to registrar"
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

        container cloudflare "Container-Cloudflare" {
            include *
            autolayout lr
            description "Level 2 — Cloudflare containers."
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
