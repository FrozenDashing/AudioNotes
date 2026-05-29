# Keep JNA and Vosk classes used by native code to avoid R8 stripping/mangling
-keep class com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn com.sun.jna.**
-dontwarn org.vosk.**

# If you include any project-specific Vosk/JNA bridge classes, keep them as well
-keep class com.audionotes.audio_notes.** { *; }
-dontwarn com.audionotes.audio_notes.**
