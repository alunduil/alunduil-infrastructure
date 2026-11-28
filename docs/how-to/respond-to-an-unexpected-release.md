<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Respond to an unexpected release

Use this when an alert fires in Grafana's **Releases** folder or the IRM
**Release tags** or **Release changes** integration:

- **`<repository>` version has no tag** fires when Hackage or PyPI holds a
  version that matches no tag in the repository.
- **`<repository>` Release by an unexpected account** fires for a day after
  someone other than the operator publishes a Release.
- **`<repository>` tag `<tag>` pushed by `<account>`** fires when someone
  other than the operator pushes a tag.
- **`<repository>` Release `<tag>` `<action>` by `<account>`** fires when
  anyone edits, unpublishes, or deletes a published Release, or flips its
  prerelease flag. It fires for your own changes too.

If you didn't make the change, [restore the
Release](#restore-a-changed-release), then [revoke the
credential](#revoke-the-credential-that-published-it).

Neither registry can take back a download. Deprecating or yanking a version
only stops new installs from choosing it, so revoke the credential before
withdrawing the version.

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

4. For a tag, read who pushed it and when:

   ```sh
   gh api repos/alunduil/<repository>/rulesets/rule-suites \
     --jq '.[] | select(.ref == "refs/tags/<tag>") | {actor_name, pushed_at}'
   ```

   A token acting as your account also shows as your account, so treat a tag
   you didn't push as unexpected.

5. If you made the release yourself without a tag, create the tag on the
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

- **PyPI:** `zfs-replicate` holds no token. Remove its trusted publisher from
  the project's **Publishing** settings on PyPI, and restore it once you know
  which run published.
- **`woodland-generators`:** delete the `PAT_TOKEN` personal access token
  under GitHub's **Settings > Developer settings**, then create a new one and
  set it:

  ```sh
  gh secret set PAT_TOKEN --repo alunduil/woodland-generators
  ```

- **A tag from another account or an App:** remove the collaborator, or
  revoke the App's private key on its **General** settings page.

## Withdraw the version

- **Hackage:** deprecate the version at
  `https://hackage.haskell.org/package/<package>/preferred/edit`. Hackage
  keeps the upload, and a build that pins the exact version still gets it.
- **PyPI:** yank the release from the project's release management page on
  PyPI. An exact `==` pin still installs a yanked release. Deleting the release
  instead is permanent, and PyPI never accepts that version's filename again.
- **`woodland-generators`:** Foundry installs from the latest Release, so
  delete the Release and its tag. Deleting a tag needs the admin role.

  ```sh
  gh release delete <tag> --repo alunduil/woodland-generators --cleanup-tag
  ```

- **A tag that published nothing:** delete it, which needs the admin role.

  ```sh
  gh api -X DELETE repos/alunduil/<repository>/git/refs/tags/<tag>
  ```

## Restore a changed Release

The alert group in IRM keeps the webhook payload, which holds the Release as
GitHub sent it.

- **Edited notes or name:** the payload's `changes` holds the old value. Set
  it back:

  ```sh
  gh release edit <tag> --repo alunduil/<repository> \
    --title <old-name> --notes-file <old-notes>
  ```

- **Flipped prerelease flag:** set it back with `--prerelease=true` or
  `--prerelease=false`. On `collection-json.hs`, a flip to prerelease starts
  the release workflow, which uploads a Hackage candidate. Cancel that run.
- **Unpublished:** publish it again:

  ```sh
  gh release edit <tag> --repo alunduil/<repository> --draft=false
  ```

- **Deleted:** the deletion also removed its assets. Recreate it as a draft
  from the payload's `release.name` and `release.body`:

  ```sh
  gh release create <tag> --repo alunduil/<repository> --verify-tag --draft \
    --title <name> --notes-file <notes>
  ```

  On `woodland-generators`, re-run the tag's `tag.yml` run, which attaches
  the assets and publishes the draft:

  ```sh
  gh run list --repo alunduil/woodland-generators --workflow tag.yml \
    --branch <tag> --json databaseId --jq '.[0].databaseId'
  gh run rerun <run-id> --repo alunduil/woodland-generators
  ```

  Elsewhere, publish the draft with `gh release edit <tag> --draft=false`.

## Check what else it reached

1. Read the publishing run's log for the commit it built and the environment
   approval it waited on:

   ```sh
   gh run view <run-id> --repo alunduil/<repository> --log
   ```

2. Check every other publishing repository's registry page and Releases for
   versions from the same period.

3. File an issue recording what was published, how, and which credential
   published it. Link the matching finding's issue in the [release path
   threat model](../explanation/threat-model-release-path.md).
