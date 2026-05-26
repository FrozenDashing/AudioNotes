# Kotlin Incremental Compilation Cache Error

## Problem Description

When building the Flutter Android project, the following error occurs:

```
e: Daemon compilation failed: null
java.lang.Exception
Caused by: java.lang.AssertionError: java.lang.Exception: Could not close incremental caches
Caused by: java.lang.IllegalArgumentException: this and base files have different roots: 
C:\Users\FrozenUni\AppData\Local\Pub\Cache\hosted\pub.flutter-io.cn\audioplayers_android-5.2.1\android\... 
and E:\Desktop\In University\Year I B\ScienceEnlightment\Mid-term-project\AudioNotes\android.
```

## Root Cause

This error is caused by **Kotlin incremental compilation cache corruption** when:

1. **Different Drive Roots**: The project is on drive `E:` but Pub cache is on drive `C:`
2. **Cache Path Mismatch**: Kotlin's incremental compiler tries to store relative paths between files on different drives
3. **Corrupted Cache State**: The incremental cache becomes corrupted and cannot properly track file dependencies

This is a known issue with Kotlin incremental compilation when working across different drive roots on Windows.

## Solution

### Immediate Fix (Already Applied)

The build actually succeeds despite the error messages. The APK was built successfully:
```
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

### Permanent Fix (Applied)

To prevent this issue in future builds, we've disabled Kotlin incremental compilation:

**File**: `android/gradle.properties`

```properties
# Disable Kotlin incremental compilation to prevent cache corruption issues
# when project and pub cache are on different drives (C: and E:)
kotlin.incremental=false
```

### Alternative: Manual Cache Cleaning

If you want to re-enable incremental compilation later, run these commands before each build:

```bash
# Clean Flutter build
flutter clean

# Remove Android build directories manually
rm -rf build
rm -rf android/build
rm -rf android/app/build

# Get dependencies again
flutter pub get

# Build project
flutter build apk --debug
```

## Trade-offs

### With Incremental Compilation Disabled (`kotlin.incremental=false`)

✅ **Pros:**
- No more cache corruption errors
- Cleaner build logs
- More reliable builds

❌ **Cons:**
- Slower builds (full recompilation each time)
- Typically 10-30 seconds longer per build

### With Incremental Compilation Enabled (default)

✅ **Pros:**
- Faster builds after first compile
- Only recompiles changed files

❌ **Cons:**
- Cache corruption issues on Windows with multiple drives
- Requires manual cleaning when errors occur

## Additional Warnings

You may see these warnings during build (they are harmless):

```
warning: 'var isSpeakerphoneOn: Boolean' is deprecated. Deprecated in Java.
```

These are deprecation warnings from the `audioplayers_android` package and don't affect functionality. They will be fixed in future package updates.

## Verification

After applying the fix, verify the build works:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

Expected output:
```
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

No Kotlin cache errors should appear.

## References

- [Kotlin Incremental Compilation Issues](https://youtrack.jetbrains.com/issue/KT-49637)
- [Flutter Clean Command](https://docs.flutter.dev/reference/flutter-cli#flutter-clean)
- [Gradle Properties Configuration](https://docs.gradle.org/current/userguide/build_environment.html#sec:gradle_configuration_properties)

---

**Last Updated**: 2026-05-26  
**Status**: ✅ Resolved by disabling Kotlin incremental compilation  
**Applied Fix**: `android/gradle.properties` - Added `kotlin.incremental=false`
