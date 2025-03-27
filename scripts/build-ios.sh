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
args=()
for arg in "$@"; do
  if [[ "$arg" != "-mmacos-version-min="* ]]; then
    args+=("$arg")
  fi
done
clang "${args[@]}" -mios-simulator-version-min=14.0
EOF
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
