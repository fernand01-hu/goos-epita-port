{ pkgs ? import <nixpkgs> {}
, withWayland ? false
}:

pkgs.callPackage ./package.nix {
  inherit withWayland;
}
