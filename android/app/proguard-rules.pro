# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# App native FGS / MethodChannel bridge
-keep class com.lukacode.sosapp.** { *; }

# Play Services / Firebase / Gson-style reflection
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions
-keep public class * extends java.lang.Exception
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Google Play Services location / activity recognition
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Crashlytics readable stacks
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# AdMob / Maps
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.**
