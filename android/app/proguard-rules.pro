# Flutter — keep plugin registrars
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase / Google Play Services
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Firestore model serialization — keep all fields accessed via reflection
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Kotlin coroutines / serialization
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep Enum names used in Firebase documents
-keepclassmembers enum * { *; }

# Flutter engine references Play Core for deferred components but we don't use them.
# R8 errors on the missing stubs — suppress the warnings instead of adding the dependency.
-dontwarn com.google.android.play.core.**
