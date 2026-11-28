<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Respond to an unexpected release

Use this when an alert in Grafana's **Releases** folder fires:

- **`<repository>` version has no tag** fires when Hackage or PyPI holds a
  version that matches no tag in the repository.
- **`<repository>` Release by an unexpected account** fires when someone
  other than the operator published a Release in the last day.

Neither registry can take back a download. Deprecating or yanking a version
only stops new installs from choosing it. That makes rotating the credential
the most urgent step.

## Decide whether the release is yours

1. Read the alert's `version` or `tag` label, and its `repository` label.

2. List the repository's recent release runs, and what triggered each one:

   ```sh
   gh run list --repo alunduil/<repository> --workflow release.yml \
     --json databaseId,event,headBranch,headSha,createdAt,conclusion
   ```

3. For a Release, read who published it:

   ```sh
   gh api repos/alunduil/<repository>/releases/tags/<tag> \
     --jq '{author: .author.login, created_at, published_at}'
   ```

4. If you made the release yourself without a tag, create the tag on the
   commit you released and stop here. If that commit is gone, add the version
   to the repository's `untagged` list in
   `terraform/alunduil/release_watch.tf` instead.

If you didn't make the release, carry on below.

## Revoke the credential that published it

Hackage tokens authenticate as a Hackage user, not a package. A leaked token
can upload every package that user maintains, so revoke both tokens even if
only one package is affected.

- **Hackage:** revoke the tokens from your Hackage account's management
  page. Then create new ones and set them on each repository's `hackage`
  environment:

  ```sh
  gh secret set HACKAGE_TOKEN --repo alunduil/collection-json.hs --env hackage
  gh secret set HACKAGE_API_KEY --repo alunduil/network-arbitrary --env hackage
  ```

- **PyPI:** `zfs-replicate` publishes through a trusted publisher and holds no
  token. Remove the publisher under the project's **Publishing** settings on
  PyPI until you know which run published.
- **`woodland-generators`:** delete the `PAT_TOKEN` personal access token
  under GitHub's **Settings > Developer settings**, then create a new one and
  set it:

  ```sh
  gh secret set PAT_TOKEN --repo alunduil/woodland-generators
  ```

## Withdraw the version

- **Hackage:** deprecate the version at
  `https://hackage.haskell.org/package/<package>/preferred/edit`. Hackage
  keeps the upload, and a build that pins the exact version still gets it.
- **PyPI:** yank the release from the project's release management page on
  PyPI. An exact `==` pin still installs a yanked release. Deleting the release
  instead is permanent, and PyPI never accepts that version's filename again.
- **`woodland-generators`:** Foundry installs from the latest Release, so
  delete the Release and its tag:

  ```sh
  gh release delete <tag> --repo alunduil/woodland-generators --cleanup-tag
  ```

The tag rulesets allow only the admin to delete a tag.

## Check what else it reached

1. Read the publishing run's log for the commit it built and the environment
   approval it waited on:

   ```sh
   gh run view <run-id> --repo alunduil/<repository> --log
   ```

2. Check every other publishing repository's registry page and Releases for
   versions from the same period. A Hackage token reaches every package its
   user maintains.

3. File an issue recording what was published, how, and which credential
   published it. If the credential came from a flow in the [release path
   threat model](../explanation/threat-model-release-path.md), link that
   finding's issue.
