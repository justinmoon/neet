#!/bin/bash
set -ex

# Fix cross-compilation issues
unset MACOSX_DEPLOYMENT_TARGET
export IPHONEOS_DEPLOYMENT_TARGET="14.0"

# Make sure we use the iOS simulator SDK
export SDKROOT=$(xcrun -sdk iphonesimulator --show-sdk-path)

# Create compiler wrapper to avoid macOS flags
mkdir -p .build/ios-wrapper
cat > .build/ios-wrapper/clang-ios-sim << 'EOF'
#!/bin/bash
set -e

# Only use Nix-provided clang
if [ -z "$NIX_CLANG_PATH" ]; then
  echo "ERROR: NIX_CLANG_PATH environment variable not set - unable to find Nix clang" >&2
  exit 1
fi

# # Get SDK path from Nix-provided xcrun
# if [ -z "$NIX_XCRUN_PATH" ]; then
#   echo "ERROR: NIX_XCRUN_PATH environment variable not set - unable to find Nix xcrun" >&2
#   exit 1
# fi

# Force override any SDK paths to use Nix-managed SDK
SIMULATOR_SDK_PATH="$NIX_SDK_PATH"
if [ -z "$SIMULATOR_SDK_PATH" ] || [ ! -d "$SIMULATOR_SDK_PATH" ]; then
  echo "ERROR: NIX_SDK_PATH environment variable not set or invalid - unable to find iOS Simulator SDK" >&2
  exit 1
fi

# Filter out macOS flags
args=()
for arg in "$@"; do
  if [[ "$arg" != "-mmacos-version-min="* ]]; then
    args+=("$arg")
  fi
done

# Log what we're doing (for debugging)
echo "Using clang: $NIX_CLANG_PATH" >&2
echo "Using simulator SDK: $SIMULATOR_SDK_PATH" >&2

# Call clang with explicit simulator flags
"$NIX_CLANG_PATH" "${args[@]}" -isysroot "$SIMULATOR_SDK_PATH" -mios-simulator-version-min=14.0
EOF

# Set paths to Nix tools to pass to our wrapper
export NIX_CLANG_PATH="${DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
# export NIX_XCRUN_PATH="${DEVELOPER_DIR}/usr/bin/xcrun"
export NIX_SDK_PATH="${DEVELOPER_DIR}/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"

# Verify the Nix tools exist
if [ ! -f "$NIX_CLANG_PATH" ]; then
  echo "ERROR: Could not find Nix clang at $NIX_CLANG_PATH"
  exit 1
fi

# if [ ! -f "$NIX_XCRUN_PATH" ]; then
#   echo "ERROR: Could not find Nix xcrun at $NIX_XCRUN_PATH"
#   exit 1
# fi

if [ ! -d "$NIX_SDK_PATH" ]; then
  echo "ERROR: Could not find iOS Simulator SDK at $NIX_SDK_PATH"
  exit 1
fi
chmod +x .build/ios-wrapper/clang-ios-sim

# Set compiler variables for this build process only
export CC_aarch64_apple_ios_sim="$(pwd)/.build/ios-wrapper/clang-ios-sim"
export CARGO_TARGET_AARCH64_APPLE_IOS_SIM_LINKER="$(pwd)/.build/ios-wrapper/clang-ios-sim"

cd rust

BUILD_TYPE=$1

echo "Building for $BUILD_TYPE"
if [ "$BUILD_TYPE" == "release" ] || [ "$BUILD_TYPE" == "--release" ]; then
    BUILD_FLAG="--release"
elif [ "$BUILD_TYPE" == "debug" ] || [ "$BUILD_TYPE" == "--debug" ] ; then
    BUILD_FLAG=""
else
    BUILD_FLAG="--profile $BUILD_TYPE"
fi

# Make sure the directory exists
mkdir -p ios/Neet.xcframework bindings ios/Neet

# Build the dylib
cargo build
 
# Generate bindings
cargo run --bin uniffi-bindgen generate --library ./target/debug/libneet.dylib --language swift --out-dir ./bindings
 
# Add the iOS targets and build
for TARGET in \
        aarch64-apple-ios-sim
        # aarch64-apple-darwin \
        # aarch64-apple-ios \
        # x86_64-apple-darwin \
        # x86_64-apple-ios
do
    # rustup target add $TARGET
    cargo build --target=$TARGET $BUILD_FLAG
done
 
# Rename *.modulemap to module.modulemap
mv ./bindings/neetFFI.modulemap ./bindings/module.modulemap
 
# Move the Swift file to the project
rm ./ios/Neet/Neet.swift || true
mv ./bindings/neet.swift ./ios/Neet/Neet.swift
 
# Recreate XCFramework
rm -rf "ios/Neet.xcframework" || true
        # -library ./target/aarch64-apple-ios/release/libcove.a -headers ./bindings \
xcodebuild -create-xcframework \
        -library ./target/aarch64-apple-ios-sim/debug/libneet.a -headers ./bindings \
        -output "ios/Neet.xcframework"
 
# Cleanup
rm -rf bindings
