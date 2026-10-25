# Qt's Java side is called from C++ through JNI (QJniObject, registered natives): keep all of it as is.
-keep class org.qtproject.qt.** { *; }
-keepclasseswithmembernames class * { native <methods>; }
# AndroidDocuments and Qt call these Android/AndroidX classes by name
-keep class androidx.core.content.FileProvider { *; }
-dontobfuscate
-dontwarn **
