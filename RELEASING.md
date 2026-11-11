# Publishing a release

The `skopea` terminal is built in a private repository; this public repository publishes it.
Signing and publishing happen **here only**, in the workflow
[`Publish a release`](.github/workflows/publish.yml).

1. In the private repository, push the tag `cli-v<version>`. The "CLI — release" workflow
   builds the four binaries, the unsigned `.deb` and `.rpm` packages and `SHA256SUMS`, and keeps
   them as an artifact for 30 days. It publishes nothing and holds no publishing secret.
2. Here, run **Actions > Publish a release > Run workflow** with `version = <version>`.
   - `stage` downloads that artifact, checks every checksum and that the binary says the commit
     of the tag, and computes the channels and the Homebrew formulae. Its summary shows the
     version, the commit and the checksums.
   - `publish` waits for an approval. **Read the summary of `stage` before approving.** Once
     approved, it signs the rpms, creates the release, rebuilds the signed apt and dnf
     repositories on packages.skopea.io, updates the Homebrew tap and this front page.
   - `verify` installs from apt, dnf and the install script.

## Where the secrets live

| Environment | Protection | Secrets and variables |
|---|---|---|
| `stage` | deployments from `main` only | variable `SKOPEA_STAGE_APP_ID`, secret `SKOPEA_STAGE_APP_PRIVATE_KEY`: a GitHub App with Contents and Actions **read**, installed on the private repository only. The job mints a one-hour token, revoked at the end of the job |
| `packages` | required reviewer, deployments from `main` only | secrets `SKOPEA_PACKAGES_GPG_PRIVATE_KEY` (the signing subkey only), `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `SKOPEA_RELEASE_APP_PRIVATE_KEY`; variables `R2_ACCOUNT_ID`, `SKOPEA_PACKAGES_BUCKET`, `SKOPEA_RELEASE_APP_ID` |

The `publish` job installs no npm package and runs only this repository's scripts
(`packaging/build-repos.sh`). What `stage` hands over is data: binaries, packages, the channels
plan, the formulae, the front-page files. `publish` checks it before using it.
