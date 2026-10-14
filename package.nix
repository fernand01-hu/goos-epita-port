{ lib
, stdenv
, cmake
, ninja
, pkg-config
, gtk4
, SDL2
, SDL2_mixer
, gdk-pixbuf
, libX11
, libXtst
, libXi
, libsysprof-capture
, pcre2
, wrapGAppsHook4
, withWayland ? false
, gtk4-layer-shell ? null
, wayland ? null
, wayland-scanner ? null
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "desktop-goose" + lib.optionalString (!withWayland) "-i3";
  version = "0.31";

  src = lib.cleanSource ./.;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    wrapGAppsHook4
  ] ++ lib.optionals withWayland [
    wayland-scanner
  ];

  buildInputs = [
    gtk4
    SDL2
    SDL2_mixer
    gdk-pixbuf
    libX11
    libXtst
    libXi
    libsysprof-capture
    pcre2
  ] ++ lib.optionals withWayland [
    gtk4-layer-shell
    wayland
  ];

  cmakeFlags = [
    "-DBUILD_TESTING=OFF"
    "-DENABLE_WAYLAND=${if withWayland then "ON" else "OFF"}"
    "-DENABLE_LAYER_SHELL=${if withWayland then "ON" else "OFF"}"
  ];

  meta = with lib; {
    description = "Desktop Goose ported natively to Linux X11 and i3wm";
    homepage = "https://github.com/jeffthepineapple/desktop-goose-linux-port";
    license = licenses.mit;
    mainProgram = "CppGoose";
    platforms = platforms.linux;
  };
})
