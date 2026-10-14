# Desktop Goose on Minimal NixOS with i3wm

This document details how to install and configure Desktop Goose (**CppGoose**) on a minimal **NixOS** installation using the **i3** window manager.

---

## 1. Prerequisites for i3wm on NixOS

On X11 window managers like i3wm, transparent windows require an X11 compositing manager. Without a compositor running, transparent regions around the goose will render as a black box.

In your NixOS configuration (`/etc/nixos/configuration.nix`), ensure **i3** and **picom** are enabled:

```nix
{ pkgs, ... }:

{
  # Enable X11 and i3
  services.xserver = {
    enable = true;
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu
        i3status
        i3lock
      ];
    };
  };

  # Required for transparent click-through overlay
  services.picom = {
    enable = true;
    backend = "glx"; # or "xrender"
    vSync = true;
  };
}
```

---

## 2. Installation Options

### Option A: Using the NixOS Module (Recommended with Flakes)

In your system `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    desktop-goose.url = "git+file:///path/to/goos-desktop-i3-port"; # or github URL
  };

  outputs = { self, nixpkgs, desktop-goose, ... }: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        desktop-goose.nixosModules.default
        {
          services.desktop-goose = {
            enable = true;
            # Automatically enables picom compositor for transparency:
            enablePicom = true;
            # Autostart Desktop Goose when your graphical session begins:
            autostart = true;
          };
        }
      ];
    };
  };
}
```

---

### Option B: Using the Minimal Package Directly in `environment.systemPackages`

If you manage packages manually in your system or Home Manager configuration:

```nix
environment.systemPackages = [
  # Pure minimal X11/i3 build (no Wayland or layer-shell dependencies)
  inputs.desktop-goose.packages.${pkgs.system}.i3
];
```

Then in your `~/.config/i3/config`:

```i3
# Start compositor (if not managed by systemd)
exec --no-startup-id picom -b

# Start Desktop Goose on login
exec --no-startup-id CppGoose
```

---

### Option C: Traditional Nix (Without Flakes)

You can build and run it directly using `default.nix`:

```bash
# Build the minimal i3 package
nix-build -E '(import <nixpkgs> {}).callPackage ./package.nix { withWayland = false; }'

# Run the binary
./result/bin/CppGoose
```

Or install it into your user profile:

```bash
nix-env -f default.nix -i
```

---

## 3. Controlling the Goose

Once running, you can interact with the goose from any terminal:

```bash
# Check status and resource usage
CppGoose status

# Open interactive control shell
CppGoose shell

# Spawn more geese
CppGoose spawn "Honk Master"

# Change or equip skin presets
CppGoose skins equip party

# Dismiss and exit
CppGoose quit
```

Holding the **Escape** key for 2 seconds on your desktop will also safely dismiss all geese.
