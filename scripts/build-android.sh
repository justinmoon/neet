#!/bin/bash
set -ex
cd rust

# export NDK_HOME=/Users/justin/Library/Android/sdk/ndk/26.1.10909125/
# export CFLAGS="--sysroot=$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
# export LDFLAGS="-L$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib"
 
# Set up cargo-ndk and add the Android targets
cargo install cargo-ndk
rustup target add aarch64-linux-android \
    armv7-linux-androideabi \
    i686-linux-android \
    x86_64-linux-android
 
# Build the dylib
# FIXME: add debug / release flag
cargo build

# FIXME: don't always build in release mod 
# Build the Android libraries in jniLibs
        # -t armeabi-v7a \
        # -t arm64-v8a \
        # -t x86 \
        # -t x86_64 \

# armeabi-v7a needed by xiaomi a3
# arm64-v8a needed by pixel 3a emulator
cargo ndk -o ../android/app/src/main/jniLibs \
        --manifest-path ./Cargo.toml \
        -t armeabi-v7a \
        -t arm64-v8a \
        build --release
 
# Create Kotlin bindings
cargo run --bin uniffi-bindgen generate \
    --library ./target/debug/libneet.dylib \
    --language kotlin \
    --out-dir ../android/app/src/main/java/com/rmp/neet