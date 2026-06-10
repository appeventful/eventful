# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Pigeon generated classes
-keep class io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$** { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin { *; }
-keep class io.flutter.plugins.firebase.core.** { *; }

# Keep models (Important for Firestore serialization if used)
-keep class com.fatih.eventful.models.** { *; }

# Google Play Core (Fixes R8 missing classes error)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
