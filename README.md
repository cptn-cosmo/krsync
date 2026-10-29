# KRsync

A Qt 6 / Kirigami front end for rsync, in the spirit of Grsync but built for Plasma: Wayland native, FormCard-style settings, live progress in the task manager, and a searchable log.

## Features

- **Sessions**: save each source → destination pair with its own options. You can rename, duplicate, reorder, import and export them.
- **Grsync compatible**: import `~/.grsync/grsync.ini` or exported `.grsync` files, and export sessions back to the same format.
- **Every Grsync option**, grouped and explained:
  - **Preserve**: times, permissions, owner, group, symlinks, hard links, devices, ACLs, extended attributes
  - **Comparison**: skip newer, ignore existing, existing only, size only, checksum, Windows compatibility
  - **Deletion**: delete with a choice of timing, delete excluded files, max-delete
  - **Transfer**: compression, partial files, whole files, one filesystem, no recursion, bandwidth limit, remote shell, protect arguments, numeric IDs
  - **Exclude patterns** and **backups** (folder and suffix)
  - **Output**: verbose, itemized, statistics
  - **Advanced**: additional options, run as administrator (pkexec), commands before and after the sync
- **Trailing-slash helper**: a switch that explains whether the folder itself or only its contents is copied.
- **Simulate** (dry run) before syncing. Sessions that delete files ask for confirmation first.
- **Live dashboard**: progress ring, speed, time left, files and deletions; pause, resume and cancel.
- **Plasma integration**: progress on the task-manager entry, sleep inhibited while syncing, a notification when a sync finishes in the background, and drag and drop from Dolphin.

## Building

Dependencies (Arch package names): `cmake extra-cmake-modules qt6-base qt6-declarative kirigami kirigami-addons kcoreaddons ki18n kconfig knotifications kcrash kdbusaddons kiconthemes qqc2-desktop-style rsync`.

```sh
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=$HOME/.local
cmake --build build
./build/bin/krsync          # or: cmake --install build
```

Installing is optional, but notifications and the app icon only work once the `.notifyrc`, `.desktop` and icon files are installed.

### Arch Linux

`packaging/arch/PKGBUILD` builds the release tarball attached to the Forgejo release:

```sh
cd packaging/arch && makepkg -si
```

## Command line

```sh
krsync --execute "Photos"                     # sync a session by name, like grsync -e
krsync --simulate "Photos" --close-when-done  # dry run, then quit (exit code 0 means success)
krsync --import backup.grsync                 # import Grsync session files
```

Running `krsync` a second time hands its arguments to the window that is already open.
