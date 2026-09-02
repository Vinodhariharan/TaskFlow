# Flutter's Gradle plugin turns on R8 (isMinifyEnabled = true) for release
# builds and automatically picks this file up if it exists. Without the rules
# below, release APKs threw
#   java.lang.RuntimeException: Missing type parameter.
#     at com.google.gson.reflect.TypeToken.<init>
#     at FlutterLocalNotificationsPlugin.loadScheduledNotifications
# because R8 strips the generic signatures Gson's TypeToken needs to resolve
# ArrayList<NotificationDetails>. That threw on *every* schedule/cancel call,
# so reminders silently never fired in release builds while working fine in
# debug. See flutter_local_notifications' "Release build configuration".

##---------------Begin: Gson ----------
# Gson reads generic type information out of the class file; R8 removes it by
# default. This single attribute is what actually fixes "Missing type
# parameter." — the TypeToken keeps below are the R8 3.0+ companions to it.
-keepattributes Signature
-keepattributes *Annotation*

-dontwarn sun.misc.**

# Prevent R8 from stripping interface information from TypeAdapter,
# TypeAdapterFactory, JsonSerializer, JsonDeserializer instances (so they can
# be used with @JsonAdapter).
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep fields annotated with @SerializedName, otherwise R8 can leave the
# deserialized objects' members null.
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Retain generic signatures of TypeToken and its subclasses (R8 3.0+).
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
##---------------End: Gson ----------

# flutter_local_notifications persists its scheduled notifications as Gson
# JSON, including a RuntimeTypeAdapterFactory over its model classes, so those
# models must keep their names and members to round-trip.
-keep class com.dexterous.** { *; }

# home_widget: WorkManager instantiates HomeWidgetBackgroundWorker reflectively
# from a class name it stored, and the widget providers reach the plugin's
# helper classes the same way. R8 has no static reference to follow for the
# worker, so without this the widget tick buttons would fail in release builds
# only — the same shape of bug as the Gson/TypeToken one above.
-keep class es.antonborri.home_widget.** { *; }

# androidx.work looks its workers up by name too.
-keep class * extends androidx.work.ListenableWorker { *; }

# The Tasks widget's list is bound by the system through RemoteViewsService,
# which reaches the factory reflectively. Manifest-declared services survive
# on their own, but this project has been bitten twice by release-only R8
# stripping (Gson signatures, then WorkManager workers), so it's spelled out.
-keep class * extends android.widget.RemoteViewsService { *; }
-keep class * implements android.widget.RemoteViewsService$RemoteViewsFactory { *; }

