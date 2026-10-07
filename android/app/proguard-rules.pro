# ===== General =====
-keepattributes Signature, InnerClasses, EnclosingMethod, Exceptions, *Annotation*, JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ===== Flutter =====
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.**

# ===== Google Play Services / Firebase =====
-keep public class com.google.android.gms.ads.** { public *; }
-keep class com.google.android.gms.ads.identifier.** { *; }
-keep class com.google.android.gms.appset.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# ===== Unity LevelPlay (+ Flutter plugin) =====
-keep class com.ironsource.** { *; }
-keep class com.unity3d.mediation.** { *; }
-keep class com.unity.levelplay.** { *; }
-dontwarn com.ironsource.**
-dontwarn com.unity3d.mediation.**

# ===== Unity Ads =====
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

# ===== Chartboost =====
-keep class com.chartboost.sdk.** { *; }
-dontwarn com.chartboost.sdk.**

# ===== Meta Audience Network =====
-keep class com.facebook.ads.** { *; }
-dontwarn com.facebook.ads.**

# ===== InMobi =====
-keep class com.inmobi.** { *; }
-dontwarn com.inmobi.**
-dontwarn com.squareup.picasso.**

# ===== Mintegral =====
-keep class com.mbridge.** { *; }
-keep interface com.mbridge.** { *; }
-dontwarn com.mbridge.**
-keep class **.R$* { public static final int mbridge*; }

# ===== MobileFuse =====
-keep class com.mobilefuse.** { *; }
-dontwarn com.mobilefuse.**

# ===== Moloco =====
-keep class com.moloco.** { *; }
-dontwarn com.moloco.**

# ===== Ogury =====
-keep class co.ogury.** { *; }
-keep class com.ogury.** { *; }
-dontwarn co.ogury.**
-dontwarn com.ogury.**

# ===== PubMatic =====
-keep class com.pubmatic.sdk.** { *; }
-dontwarn com.pubmatic.sdk.**

# ===== Smaato =====
-keep class com.smaato.sdk.** { *; }
-dontwarn com.smaato.sdk.**

# ===== Verve (HyBid) =====
-keep class net.pubnative.** { *; }
-dontwarn net.pubnative.**

# ===== Yandex =====
-keep class com.yandex.mobile.ads.** { *; }
-dontwarn com.yandex.mobile.ads.**

# ===== Vungle (Liftoff) =====
-keep class com.vungle.** { *; }
-dontwarn com.vungle.**

# ===== AppLovin =====
-keep class com.applovin.** { *; }
-dontwarn com.applovin.**

# ===== IAB OMID / Moat =====
-keep class com.iab.omid.library.** { *; }
-dontwarn com.iab.omid.**
-dontwarn com.moat.**

# ===== Common missing-class warnings =====
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
