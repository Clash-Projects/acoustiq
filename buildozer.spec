[app]
title = FLAC Audio Toolkit
package.name = flactoolkit
package.domain = org.flac
source.dir = .
source.include_exts = py,png,jpg,kv,atlas

version = 1.0.0
requirements = python3==3.11.6,kivy==2.3.0,hostpython3==3.11.6

orientation = portrait
fullscreen = 0

# Android specific
android.permissions = READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE,MANAGE_EXTERNAL_STORAGE
android.api = 33
android.minapi = 24
android.ndk = 25b
android.archs = arm64-v8a
android.allow_backup = True
android.accept_sdk_license = True

# Pin p4a to stable 2024.01 release (uses Python 3.11, avoids cp314 issues)
p4a.branch = v2024.01.21

[buildozer]
log_level = 2
warn_on_root = 1

