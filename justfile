default:
    just --list

# env:
#     export ANDROID_HOME=/Users/justin/Library/Android/sdk
#     alias emulator=$ANDROID_HOME/emulator/emulator

run-emulator:
    # FIRST_AVD=$(/Users/justin/Library/Android/sdk/emulator/emulator -list-avds | head -n 1)
    # echo "Starting emulator $FIRST_AVD"
    /Users/justin/Library/Android/sdk/emulator/emulator -avd Pixel_3a_API_34_extension_level_7_arm64-v8a &
    # TODO: wait for emulator to boot
    # TODO: skip emulator boot if already booted

build-android:
    bash scripts/build-android.sh

run-android: build-android
    bash scripts/run-android.sh

run-simulator:
    open -a Simulator

build-ios profile="debug":
    bash scripts/build-ios.sh {{profile}}

run-ios: build-ios
    bash scripts/run-ios.sh

watch: 
    watchexec --exts rs just build-ios

lint:
    cd rust
    cargo check
    cargo clippy
    cd ..

fix:
    cd rust
    cargo fix --allow-dirty
    cargo clippy --fix --allow-dirty
    cd ..

# HACK: "home" button on this emulator is broken
adb-home:
    adb shell input keyevent 3

logcat:
    adb logcat | grep "com.rmp.neet"