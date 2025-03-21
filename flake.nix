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
            # build-tools-34-0-0
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
          ];

          shellHook = ''
            # without this, adb can't run while mullvad is running for some reason ...
            export ADB_MDNS_OPENSCREEN=0

            export ANDROID_HOME=${androidSdk}/share/android-sdk
            export ANDROID_SDK_ROOT=${androidSdk}/share/android-sdk
            export ANDROID_NDK_ROOT=${androidSdk}/share/android-sdk/ndk/28.0.13004108
            export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH

            echo "Android development environment initialized!"
            echo "ANDROID_HOME: $ANDROID_HOME"
            echo "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
            echo ""
            echo "Available commands:"
            echo "  just build-android  - Build the Android app"
            echo "  just run-android    - Run the Android app on an emulator"
            echo "  just run-emulator   - Launch the Android emulator"
          '';
        };
      }
    );
  };
}
