# Receptacle — just recipes
# Run `just --list` to see all available recipes.

peek_cmd := env_var('HOME') / "Developer" / "peekaboo" / "peek"
project  := justfile_directory() / "Receptacle.xcodeproj"

# Capture the running Receptacle window (app must already be running; no build step)
peek:
    {{peek_cmd}} --app Receptacle --platform macos

# Incremental Xcode build, then capture
peek-build:
    {{peek_cmd}} \
        --app Receptacle \
        --platform macos \
        --build xcode \
        --scheme ReceptacleApp \
        --project {{project}}

# Hot-reload the running Xcode session, then capture
peek-hot:
    {{peek_cmd}} \
        --app Receptacle \
        --platform macos \
        --hot \
        --build xcode \
        --scheme ReceptacleApp \
        --project {{project}}

app_path := env_var('HOME') / "Library/Developer/Xcode/DerivedData/Receptacle-dbyztsxdyacwyraocfxnhmidheto/Build/Products/Debug/Receptacle.app"

# Relaunch via Xcode (Cmd+R), then capture (Xcode builds + runs fresh)
peek-run:
    #!/usr/bin/env zsh
    set -euo pipefail
    # Stop the current run, then Cmd+R to rebuild and relaunch
    osascript \
        -e 'tell application "Xcode" to activate' \
        -e 'tell application "System Events" to keystroke "." using {command down}'
    sleep 1
    osascript \
        -e 'tell application "Xcode" to activate' \
        -e 'tell application "System Events" to keystroke "r" using {command down}'
    # Retry until the app window is available (build + launch can take a while)
    for i in {1..20}; do
        sleep 2
        {{peek_cmd}} --app Receptacle --platform macos && exit 0 || true
    done
    echo "peek-run: timed out waiting for Receptacle to launch" >&2
    exit 1

# SPM incremental build (ReceptacleCore / CLI only)
spm-build:
    swift build

# Run ReceptacleVerify checks
verify:
    swift run ReceptacleVerify
