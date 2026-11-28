# Preserve Flutter & Android embedding entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter embedding optional Play Core deferred components
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep ClashPlayer native C/JNI bridges (libnativeout.so, libusbiso.so) & Kotlin USB audio classes
-keep class com.clashplayer.** { *; }
-keepclassmembers class com.clashplayer.** { *; }

# Keep AcoustiQ Android entry point & native audio bridge
-keep class com.clashprojects.acoustiq.** { *; }
-keepclassmembers class com.clashprojects.acoustiq.** { *; }
