[app]
title = FLAC Audio Toolkit
package.name = flactoolkit
package.domain = org.flac
source.dir = .
source.include_exts = py,png,jpg,kv,atlas

version = 1.0.0
requirements = python3,kivy,mutagen,numpy

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

[buildozer]
log_level = 2
warn_on_root = 1

