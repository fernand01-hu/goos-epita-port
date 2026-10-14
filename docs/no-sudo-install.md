# Installing Desktop Goose Without Sudo Privileges

This guide explains how to install and run **Desktop Goose** (`CppGoose`) on **any** Linux computer entirely within your user home directory (`~/.local`) without requiring any `sudo` or root privileges.

---

## 1. Quick Install (From Repository)

If you have cloned the repository onto your machine:

```bash
./install.sh
```

The script will automatically:
1. Detect any precompiled binary, or build one without sudo using **Nix** or **CMake**.
2. Install the executable to `~/.local/bin/CppGoose`.
3. Install all Assets (memes, sounds, text notes, mods) to `~/.local/share/CppGoose/Assets`.
4. Install an application launcher to `~/.local/share/applications/CppGoose.desktop`.
5. Install the vector icon to `~/.local/share/icons/hicolor/scalable/apps/cppgoose.svg`.
6. Verify your dynamic libraries (`ldd`), `$PATH`, and compositor.

---

## 2. Installing on ANY Computer (Portable Bundle)

If you want to install Desktop Goose on a computer that **does not have compilers, git, Nix, or root/sudo access** (such as a school/work PC, a friend's PC, or an offline machine):

### Step 1: Create the Portable Bundle (On your build machine)
Run:
```bash
./package-portable.sh
```
This generates a single archive: **`cppgoose-portable.tar.gz`**.

### Step 2: Transfer and Install (On target computer)
Copy `cppgoose-portable.tar.gz` to the target computer (via USB drive, `scp`, or download), extract it, and run:

```bash
tar -xzf cppgoose-portable.tar.gz
cd cppgoose-portable
./install.sh
```

That's it! It installs in under 2 seconds without requiring any root permissions.

---

## 3. Running & Controlling Desktop Goose

Once installed:

| Command | Action |
| :--- | :--- |
| `CppGoose` | Launch Desktop Goose |
| `CppGoose status` | Show goose count, ram usage, asset path, and active rules |
| `CppGoose shell` | Open interactive CLI control shell |
| `CppGoose spawn` | Spawn additional geese |
| `CppGoose skins` | Browse and equip skins/hats |
| `CppGoose freeze` | Freeze or unfreeze the goose |
| `CppGoose quit` | Dismiss and stop Desktop Goose |

> [!TIP]
> **Emergency Exit**: You can also dismiss Desktop Goose at any time by holding the <kbd>Esc</kbd> key for **3 seconds**.

---

## 4. Making sure `~/.local/bin` is in your PATH

If running `CppGoose` says `command not found`, add `~/.local/bin` to your `$PATH`:

```bash
# For Bash (~/.bashrc)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# For Zsh (~/.zshrc)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## 5. Notes for i3wm Users

Desktop Goose renders transparent overlays using standard 32-bit ARGB visual channels. On tiling window managers like **i3**, transparent windows require an X11 compositor:

```bash
# Start picom in background
picom -b
```

To have both start automatically when you log into i3, add these lines to `~/.config/i3/config`:

```i3config
exec --no-startup-id picom -b
exec --no-startup-id CppGoose
```

---

## 6. Uninstalling

To cleanly remove Desktop Goose and all user-space desktop integrations:

```bash
./install.sh --uninstall
```
