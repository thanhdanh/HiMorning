-dontobfuscate
-dontwarn com.google.mediapipe.**
-dontwarn com.google.mlkit.**
-keep class com.himorning.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.mediapipe.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
