{
  description = "rust-multiplatform development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    android-nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});
  in {
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};

        # Configure Android SDK
        androidSdk = android-nixpkgs.sdk.${system} (sdkPkgs:
          with sdkPkgs; [
            # Essential build tools
            cmdline-tools-latest
            build-tools-33-0-1 # FIXME: why does it want this?
            platform-tools

            # Platform & API level
            platforms-android-34

            # NDK for native code compilation
            ndk-28-0-13004108

            # Emulator for testing
            emulator
            system-images-android-34-google-apis-arm64-v8a
          ]);
      in {
        default = pkgs.mkShell {
          buildInputs = [
            androidSdk
            pkgs.just
            pkgs.watchexec
            pkgs.libtool
            pkgs.webrtc-audio-processing
            pkgs.autoconf
            pkgs.automake
            pkgs.pkg-config
          ];

          shellHook = ''
            # without this, adb can't run while mullvad is running for some reason ...
            export ADB_MDNS_OPENSCREEN=0

            export ANDROID_HOME=${androidSdk}/share/android-sdk
            export ANDROID_SDK_ROOT=${androidSdk}/share/android-sdk
            export ANDROID_NDK_ROOT=${androidSdk}/share/android-sdk/ndk/28.0.13004108
            export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH

            # Create a local bin directory for symlinks
            mkdir -p $PWD/.nix-shell/bin

            # webrtc-audio-processing looks for glibtoolize but nix installs it as libtoolize 
            # https://github.com/tonarino/webrtc-audio-processing/blob/7f62ad3e815acf22b2925aca7501e8fc901104d3/webrtc-audio-processing-sys/build.rs#L93-L97
            ln -sf "${pkgs.libtool}/bin/libtoolize" "$PWD/.nix-shell/bin/glibtoolize"
            export PATH=$PWD/.nix-shell/bin:${pkgs.libtool}/bin:$PATH
          '';
        };
      }
    );
  };
}
