# Firebase and ML Kit missing classes fix
-keep class com.google.firebase.iid.** { *; }
-dontwarn com.google.firebase.iid.**

# ML Kit specific rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**