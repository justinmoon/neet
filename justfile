default:
    just --list

create-emulator:
    avdmanager create avd --force --name emulator --package 'system-images;android-35;google_apis;arm64-v8a' --path $PWD/emulator -d pixel_6

run-emulator:
    emulator -avd emulator

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
    adb logcat | grep "neet"
