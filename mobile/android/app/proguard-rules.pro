# LiteRT-LM — keep all public API classes
-keep class com.google.ai.edge.litertlm.** { *; }
-dontwarn com.google.ai.edge.litertlm.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# Keep the MethodChannel bridge
-keep class com.encourise.encourise_mobile.** { *; }
