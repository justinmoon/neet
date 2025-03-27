{
  description = "rust-multiplatform development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    justin = { url = "github:justinmoon/flakes"; };
  };

  outputs = { self, nixpkgs, android-nixpkgs, rust-overlay, justin, }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };

          # Define Rust with cross-compilation targets for Android and iOS
          rustWithMobileTargets = pkgs.rust-bin.stable.latest.default.override {
            targets = [
              # Android
              "aarch64-linux-android"
              "armv7-linux-androideabi"
              "i686-linux-android"
              "x86_64-linux-android"
              # iOS
              "aarch64-apple-ios-sim"
            ];
            extensions = [ "rust-src" "rust-analyzer" "clippy" ];
          };

          # Configure Android SDK
          androidSdk = android-nixpkgs.sdk.${system} (sdkPkgs:
            with sdkPkgs; [
              # Essential build tools
              cmdline-tools-latest
              build-tools-35-0-0
              platform-tools

              # Platform & API level
              platforms-android-35

              # NDK for native code compilation
              ndk-28-0-13004108

              # Emulator for testing
              emulator
              system-images-android-35-google-apis-arm64-v8a
            ]);

          # Install Xcode
          xcode = justin.lib.xcode { inherit pkgs; };
        in {
          default = with pkgs;
            pkgs.mkShell {
              buildInputs = [
                androidSdk
                # android-studio

                # Rust with Android targets
                rustWithMobileTargets

                # cargo-ndk for Android builds
                pkgs.cargo-ndk

                libtool
                webrtc-audio-processing
                autoconf
                automake
                pkg-config

                # devtools
                just
                watchexec
                nixfmt-classic
                # kotlin-language-server

                # Java
                pkgs.jdk17
              ];

              shellHook = ''
                # without this, adb can't run while mullvad is running for some reason ...
                export ADB_MDNS_OPENSCREEN=0

                export ANDROID_HOME=${androidSdk}/share/android-sdk
                export ANDROID_SDK_ROOT=${androidSdk}/share/android-sdk
                export ANDROID_NDK_ROOT=${androidSdk}/share/android-sdk/ndk/28.0.13004108
                export JAVA_HOME=${pkgs.jdk17}
                export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH

                # Create a local bin directory for symlinks
                mkdir -p $PWD/.nix-shell/bin

                # webrtc-audio-processing looks for glibtoolize but nix installs it as libtoolize 
                # https://github.com/tonarino/webrtc-audio-processing/blob/7f62ad3e815acf22b2925aca7501e8fc901104d3/webrtc-audio-processing-sys/build.rs#L93-L97
                ln -sf "${pkgs.libtool}/bin/libtoolize" "$PWD/.nix-shell/bin/glibtoolize"
                export PATH=$PWD/.nix-shell/bin:${pkgs.libtool}/bin:$PATH
              '';
            };
        });
    };
}
