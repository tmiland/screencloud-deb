# screencloud-deb

Repackages the [upstream ScreenCloud](https://github.com/olav-st/screencloud)
Linux **AppImage** into a Debian/Ubuntu **`.deb`**, which upstream does not
ship. Built artifacts are published as GitHub release assets and consumed by
[deb.tmiland.com](https://deb.tmiland.com) (`packages/screencloud.pkg`).

This repository contains **no ScreenCloud source code** — only packaging
scripts. ScreenCloud is Copyright its authors and licensed under
[GPL-2.0](https://github.com/olav-st/screencloud/blob/master/LICENSE); the
corresponding source is the upstream repository at the matching release tag.

## How it works

- `.github/workflows/build-deb.yml` runs daily (and on demand). It looks up the
  latest upstream release, and if no matching release exists here yet, downloads
  the `x86_64`/`aarch64` AppImages, repackages them, and publishes a release
  `v<version>` with `screencloud_<version>_<arch>.deb`.
- `scripts/build-deb.sh` extracts the AppImage, installs the AppDir under
  `/opt/screencloud`, wires up a `/usr/bin/screencloud` launcher and desktop
  entry, and builds the package with `dpkg-deb`.

## Install

Via the tmiland APT repository:

```sh
sudo curl -SsL -o /etc/apt/sources.list.d/tmiland.list https://deb.tmiland.com/debian/tmiland.list
curl -SsL https://deb.tmiland.com/debian/KEY.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/tmiland-archive-keyring.gpg >/dev/null
sudo apt update
sudo apt install screencloud
```

Or grab a `.deb` from the [releases](../../releases) page.
