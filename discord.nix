{
  lib,
  stdenv,
  fetchurl,
  discord,
  nix,

  # Platform-specific build tools
  autoPatchelfHook, # linux
  makeDesktopItem, # linux
  makeShellWrapper, # linux
  makeWrapper,
  undmg, # darwin
  wrapGAppsHook3, # linux

  # Common
  cacert,
  coreutils, # For base64 in update script
  curl,
  gnugrep,
  sd,

  python3,
  runCommand,
  writeShellApplication,

  # Linux runtime dependencies
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libappindicator-gtk3,
  libcxx,
  libdbusmenu,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libunity,
  libuuid,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libxshmfence,
  libXtst,
  nspr,
  nss,
  pango,
  pipewire,
  speechd-minimal,
  systemd,
  wayland,

  # Options
  branch ? "stable",
  withOpenASAR ? false,
  openasar,
  withVencord ? false,
  vencord,
  enableAutoscroll ? false,

  # Linux specific options
  withTTS ? true,
}:
let
  versions = {
    linux = {
      stable = "0.0.95";
      ptb = "0.0.144";
      canary = "0.0.683";
      development = "0.0.75";
    };
    darwin = {
      stable = "0.0.346";
      ptb = "0.0.174";
      canary = "0.0.789";
      development = "0.0.88";
    };
  };

  srcs = {
    x86_64-linux = {
      stable = fetchurl {
        url = "https://stable.dl2.discordapp.net/apps/linux/${versions.linux.stable}/discord-${versions.linux.stable}.tar.gz";
        hash = "sha256-8NpHTG3ojEr8LCRBE/urgH6xdAHLUhqz+A95obB75y4=";
      };
      ptb = fetchurl {
        url = "https://ptb.dl2.discordapp.net/apps/linux/${versions.linux.ptb}/discord-ptb-${versions.linux.ptb}.tar.gz";
        hash = "sha256-URTBQ2YzkC8p7524RqR1OCqI3WkvtsClvd91RIWEQqU=";
      };
      canary = fetchurl {
        url = "https://canary.dl2.discordapp.net/apps/linux/${versions.linux.canary}/discord-canary-${versions.linux.canary}.tar.gz";
        hash = "sha256-auyunZ1UtlP+R38AfMrSYEB0fVnF3sXoXR0JxGSMtLU=";
      };
      development = fetchurl {
        url = "https://development.dl2.discordapp.net/apps/linux/${versions.linux.development}/discord-development-${versions.linux.development}.tar.gz";
        hash = "sha256-wxbmdEzJu66CqJ87cdOKH5fhWKFvD/FBaeJVFxRCvlQ=";
      };
    };
    x86_64-darwin = {
      stable = fetchurl {
        url = "https://stable.dl2.discordapp.net/apps/osx/${versions.darwin.stable}/Discord.dmg";
        hash = "sha256-sgtY3umSabTNvFNdZ5Jf5kvsxiRM9K8BtbrnxiLg0K4=";
      };
      ptb = fetchurl {
        url = "https://ptb.dl2.discordapp.net/apps/osx/${versions.darwin.ptb}/DiscordPTB.dmg";
        hash = "sha256-/suI1rVJZE1z8wLfiD65p7IdBJsJnz8zX1A2xmMMDnc=";
      };
      canary = fetchurl {
        url = "https://canary.dl2.discordapp.net/apps/osx/${versions.darwin.canary}/DiscordCanary.dmg";
        hash = "sha256-L7WuYrP13GxF7F1p44oW2M+sLJFDGUhsQkhmOk0Wo9g=";
      };
      development = fetchurl {
        url = "https://development.dl2.discordapp.net/apps/osx/${versions.darwin.development}/DiscordDevelopment.dmg";
        hash = "sha256-vjpbLg1YIXOSCwnuMwlXo7Sj8B28i812lJ3yV2NLMrE=";
      };
    };
    aarch64-darwin = srcs.x86_64-darwin;
    aarch64-linux = throw "Discord does not provide official aarch64-linux builds.";
  };

  currentPlatform = if stdenv.hostPlatform.isLinux then "linux" else "darwin";
  currentSystem = stdenv.hostPlatform.system;
  version =
    versions.${currentPlatform}.${branch}
      or (throw "Invalid branch ${branch} for platform ${currentPlatform}");
  src =
    srcs.${currentSystem}.${branch}
      or (throw "Platform ${currentSystem} not supported for branch ${branch}");

  genericMeta = {
    description = "All-in-one cross-platform voice and text chat for gamers";
    downloadPage = "https://discordapp.com/download";
    homepage = "https://discordapp.com/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      artturin
      donteatoreo
      infinidoge
      jopejoe1
      Scrumplex
    ];
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };

  packages =
    builtins.mapAttrs
      (
        key: value:
        let
          binaryName = value.binaryName;
          desktopName = value.desktopName;

          disableBreakingUpdates = discord.passthru.disableBreakingUpdates;

          libPath = lib.makeLibraryPath (
            [
              libcxx
              systemd
              libpulseaudio
              libdrm
              libgbm
              stdenv.cc.cc
              alsa-lib
              atk
              at-spi2-atk
              at-spi2-core
              cairo
              cups
              dbus
              expat
              fontconfig
              freetype
              gdk-pixbuf
              glib
              gtk3
              libglvnd
              libnotify
              libX11
              libXcomposite
              libunity
              libuuid
              libXcursor
              libXdamage
              libXext
              libXfixes
              libXi
              libXrandr
              libXrender
              libXtst
              nspr
              libxcb
              pango
              pipewire
              libXScrnSaver
              libappindicator-gtk3
              libdbusmenu
              wayland
            ]
            ++ lib.optional withTTS speechd-minimal
          );

          desktopItem = makeDesktopItem {
            name = value.pname;
            exec = lib.strings.toLower binaryName;
            icon = value.pname;
            inherit desktopName;
            genericName = genericMeta.description;
            categories = [
              "Network"
              "InstantMessaging"
            ];
            mimeTypes = [ "x-scheme-handler/discord" ];
            startupWMClass = "discord";
          };

          updateScriptDrv = (
            writeShellApplication {
              name = "discord-update";
              runtimeInputs = [
                cacert
                nix
                coreutils # For base64
                curl
                gnugrep
                sd
              ];
              text = ''
                BRANCHES=("stable" "ptb" "canary" "development")
                DEFAULT_NIX_FILE="./discord.nix"
                if [ ! -f "$DEFAULT_NIX_FILE" ]; then
                    echo "Error: Could not find Nix expression at '$DEFAULT_NIX_FILE'" >&2
                    exit 1
                fi

                tmp_file=$(mktemp)
                cp "$DEFAULT_NIX_FILE" "$tmp_file"

                update_hash_perl() {
                  local platform="$1"
                  local branch="$2"
                  local new_hash="$3"
                  PLATFORM="$platform" BRANCH="$branch" NEWHASH="$new_hash" \
                  perl -0777 -i -pe '
                    my $platform = $ENV{"PLATFORM"};
                    my $branch = $ENV{"BRANCH"};
                    my $new_hash = $ENV{"NEWHASH"};
                    s{
                      ($platform\s*=\s*\{\s*.*?
                        $branch\s*=\s*fetchurl\s*\{
                        .*?
                        hash\s*=\s*")
                        sha256-[A-Za-z0-9+/=]+
                        (";)
                      }
                      {$1$new_hash$2}xms
                    ' "$tmp_file"
                }

                for BRANCH in "''${BRANCHES[@]}"; do
                  # LINUX
                  linux_url=$(curl -sI -L -o /dev/null -w '%{url_effective}' "https://discord.com/api/download/$BRANCH?platform=linux&format=tar.gz")
                  linux_version=$(echo "$linux_url" | grep -oP 'apps/linux/\K([0-9]+\.[0-9]+\.[0-9]+)') || continue
                  linux_hash=$(nix-prefetch-url --type sha256 "$linux_url" 2>/dev/null) || continue
                  linux_sri_hash=$(nix hash convert --to sri --hash-algo sha256 "$linux_hash")

                  # DARWIN
                  darwin_url=$(curl -sI -L -o /dev/null -w '%{url_effective}' "https://discord.com/api/download/$BRANCH?platform=osx&format=dmg")
                  darwin_version=$(echo "$darwin_url" | grep -oP 'apps/osx/\K([0-9]+\.[0-9]+\.[0-9]+)') || continue
                  darwin_hash=$(nix-prefetch-url --type sha256 "$darwin_url" 2>/dev/null) || continue
                  darwin_sri_hash=$(nix hash convert --to sri --hash-algo sha256 "$darwin_hash")

                  sd "''${BRANCH}\s*=\s*\"[^\"]+\";" "''${BRANCH} = \"''${linux_version}\";" "$tmp_file"
                  sd "(darwin\s*=\s*\{(?:[^{}]|\{[^{}]*\})*\s*)''${BRANCH}\s*=\s*\"[^\"]+\";" "\''${1}''${BRANCH} = \"''${darwin_version}\";" "$tmp_file"

                  update_hash_perl "x86_64-linux" "$BRANCH" "$linux_sri_hash"
                  update_hash_perl "x86_64-darwin" "$BRANCH" "$darwin_sri_hash"

                  echo "[Nix] Finished updates for '$BRANCH'."
                done

                mv "$tmp_file" "$DEFAULT_NIX_FILE"
              '';
            }
          );

        in
        stdenv.mkDerivation (
          rec {
            inherit version src;
            pname = value.pname;

            nativeBuildInputs =
              [ makeWrapper ]
              ++ lib.optionals stdenv.hostPlatform.isLinux [
                autoPatchelfHook
                cups
                libdrm
                libuuid
                libXdamage
                libX11
                libXScrnSaver
                libXtst
                libxcb
                libxshmfence
                libgbm
                nss
                wrapGAppsHook3
                makeShellWrapper
              ]
              ++ lib.optionals stdenv.hostPlatform.isDarwin [ undmg ];

            buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
              alsa-lib
              gtk3
              systemd
              pipewire
              wayland
            ];

            runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux (lib.splitString ":" libPath);

            dontWrapGApps = lib.optional stdenv.hostPlatform.isLinux true;

            sourceRoot = lib.optionalString stdenv.hostPlatform.isDarwin ".";

            installPhase =
              if stdenv.hostPlatform.isLinux then
                ''
                  runHook preInstall

                  mkdir -p $out/{bin,opt/${binaryName},share/pixmaps,share/icons/hicolor/256x256/apps}
                  mv * "$out/opt/${binaryName}"

                  chmod +x "$out/opt/${binaryName}/${binaryName}"
                  patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
                      "$out/opt/${binaryName}/${binaryName}"

                  wrapProgramShell "$out/opt/${binaryName}/${binaryName}" \
                      "''${gappsWrapperArgs[@]}" \
                      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
                      ${lib.strings.optionalString withTTS ''
                        --run 'if [[ "''${NIXOS_SPEECH:-default}" != "False" ]]; then NIXOS_SPEECH=True; else unset NIXOS_SPEECH; fi' \
                        --add-flags "\''${NIXOS_SPEECH:+--enable-speech-dispatcher}" \
                      ''} \
                      ${lib.strings.optionalString enableAutoscroll "--add-flags \"--enable-blink-features=MiddleClickAutoscroll\""} \
                      --prefix XDG_DATA_DIRS : "${gtk3}/share/gsettings-schemas/${gtk3.name}/" \
                      --prefix LD_LIBRARY_PATH : ${libPath}:$out/opt/${binaryName} \
                      --run "${lib.getExe disableBreakingUpdates}"

                  ln -s "$out/opt/${binaryName}/${binaryName}" "$out/bin"
                  # Without || true the install would fail on case-insensitive filesystems
                  ln -s "$out/opt/${binaryName}/${binaryName}" "$out/bin/${lib.strings.toLower binaryName}" || true

                  ln -s "$out/opt/${binaryName}/discord.png" "$out/share/pixmaps/${pname}.png"
                  ln -s "$out/opt/${binaryName}/discord.png" "$out/share/icons/hicolor/256x256/apps/${pname}.png"

                  ln -s "$desktopItem/share/applications" "$out/share/"

                  runHook postInstall
                ''
              else
                ''
                  runHook preInstall

                  mkdir -p "$out/Applications"
                  cp -r "${desktopName}.app" "$out/Applications"

                  # wrap executable to $out/bin
                  mkdir -p "$out/bin"
                  makeWrapper "$out/Applications/${desktopName}.app/Contents/MacOS/${binaryName}" "$out/bin/${binaryName}" \
                    --run "${disableBreakingUpdates}/bin/disable-breaking-updates.py"

                  runHook postInstall
                '';

            postInstall =
              let
                resourcesPath =
                  if stdenv.hostPlatform.isLinux then
                    "$out/opt/${binaryName}/resources"
                  else
                    "$out/Applications/${desktopName}.app/Contents/Resources";
              in
              # OpenASAR
              lib.strings.optionalString (withOpenASAR && openasar != null) ''
                cp -f ${openasar} "${resourcesPath}/app.asar"
              ''
              # Vencord
              + lib.strings.optionalString (withVencord && vencord != null) ''
                mv ${resourcesPath}/app.asar ${resourcesPath}/_app.asar
                mkdir -p ${resourcesPath}/app.asar
                echo '{"name":"discord","main":"index.js"}' > ${resourcesPath}/app.asar/package.json
                echo 'require("${vencord}/patcher.js")' > ${resourcesPath}/app.asar/index.js
              '';

            meta = genericMeta // {
              mainProgram = "discord";
              description =
                genericMeta.description
                + lib.optionalString (withOpenASAR && openasar != null) " (with OpenASAR)"
                + lib.optionalString (withVencord && vencord != null) " (with Vencord)";
            };
            passthru = {
              inherit disableBreakingUpdates;
              updateScript = updateScriptDrv;
            };
          }
          // lib.optionalAttrs stdenv.hostPlatform.isLinux { inherit desktopItem; }
          // lib.optionalAttrs stdenv.hostPlatform.isLinux {
            inherit withTTS enableAutoscroll;
          }
        )
      )
      {
        stable = {
          pname = "discord";
          binaryName = "Discord";
          desktopName = "Discord";
        };
        ptb = rec {
          pname = "discord-ptb";
          binaryName = if stdenv.hostPlatform.isLinux then "DiscordPTB" else desktopName;
          desktopName = "Discord PTB";
        };
        canary = rec {
          pname = "discord-canary";
          binaryName = if stdenv.hostPlatform.isLinux then "DiscordCanary" else desktopName;
          desktopName = "Discord Canary";
        };
        development = rec {
          pname = "discord-development";
          binaryName = if stdenv.hostPlatform.isLinux then "DiscordDevelopment" else desktopName;
          desktopName = "Discord Development";
        };
      };
in
packages.${branch}
  or (throw "Invalid branch selected: ${branch}. Valid branches are: ${lib.concatStringsSep ", " (builtins.attrNames packages)}")
