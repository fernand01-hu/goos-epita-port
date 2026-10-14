{
  description = "Desktop Goose Linux port (with native X11 and i3wm support)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = import nixpkgs { inherit system; };
        });
    in {
      packages = forAllSystems ({ pkgs, ... }: rec {
        # Minimal X11 / i3 build without Wayland / layer-shell
        i3 = pkgs.callPackage ./package.nix { withWayland = false; };
        minimal = i3;

        # Full Wayland + X11 build
        wayland = pkgs.callPackage ./package.nix { withWayland = true; };

        # Default package is the minimal i3 build for this port
        default = i3;
      });

      apps = forAllSystems ({ pkgs, ... }: rec {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.default}/bin/CppGoose";
        };
        i3 = default;
      });

      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
          ];

          buildInputs = with pkgs; [
            gtk4
            SDL2
            SDL2_mixer
            gdk-pixbuf
            libX11
            libXtst
            libXi
            libsysprof-capture
            pcre2
          ];
        };

        full = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
            wayland-scanner
          ];

          buildInputs = with pkgs; [
            gtk4
            gtk4-layer-shell
            SDL2
            SDL2_mixer
            gdk-pixbuf
            wayland
            libX11
            libXtst
            libXi
            libsysprof-capture
            pcre2
          ];
        };
      });

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.desktop-goose;
        in {
          options.services.desktop-goose = {
            enable = lib.mkEnableOption "Desktop Goose mischievous desktop pet on X11 / i3";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              description = "The Desktop Goose package to install.";
            };

            enablePicom = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to automatically enable picom compositor.
                True X11 transparency on i3wm requires a compositor like picom.
              '';
            };

            autostart = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to autostart Desktop Goose as a systemd user service.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];

            services.picom.enable = lib.mkIf cfg.enablePicom (lib.mkDefault true);

            systemd.user.services.desktop-goose = lib.mkIf cfg.autostart {
              description = "Desktop Goose X11 Service";
              wantedBy = [ "graphical-session.target" ];
              partOf = [ "graphical-session.target" ];
              after = [ "graphical-session.target" ];
              serviceConfig = {
                ExecStart = "${cfg.package}/bin/CppGoose --foreground";
                Restart = "on-failure";
                RestartSec = "5s";
              };
            };
          };
        };

      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.desktop-goose;
        in {
          options.services.desktop-goose = {
            enable = lib.mkEnableOption "Desktop Goose on X11 / i3";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              description = "The Desktop Goose package to install.";
            };

            autostart = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to autostart Desktop Goose as a user systemd service.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];

            systemd.user.services.desktop-goose = lib.mkIf cfg.autostart {
              Unit = {
                Description = "Desktop Goose X11 Service";
                PartOf = [ "graphical-session.target" ];
                After = [ "graphical-session.target" ];
              };
              Service = {
                ExecStart = "${cfg.package}/bin/CppGoose --foreground";
                Restart = "on-failure";
                RestartSec = "5s";
              };
              Install = {
                WantedBy = [ "graphical-session.target" ];
              };
            };
          };
        };
    };
}
