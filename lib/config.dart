// ====== FILL THESE BEFORE RELEASE ======
const kClientName = 'albonik-speedtest';
const kClientVersion = '1.0.0';

// Public URL of your force-update JSON (min_version, latest_version, ...).
const kConfigUrl = 'https://YOUR_DOMAIN/speedtest_config.json';
// Your published privacy policy page (required for M-Lab + ads).
const kPrivacyUrl = 'https://albonik.com/privacy-policy/speedtest.txt';
const kMlabPolicyUrl = 'https://www.measurementlab.net/aup/';

// Unity LevelPlay (from the LevelPlay dashboard). App keys / ad unit IDs are
// not secrets, they ship inside the app.
const kLevelPlayAppKeyAndroid = '288151cfd';
const kBannerAdUnitAndroid = '7fnx7ugm7dtm9oho';
// Other Android ad units (created in the dashboard, not used in the UI yet):
const kInterstitialAdUnitAndroid = 'u6ewx9zm1skohjki';
const kNativeAdUnitAndroid = 'fvlqqx3guayw7ij7';
const kRewardedAdUnitAndroid = 't0q9ib59s65p4hts';

// iOS (separate LevelPlay app).
const kLevelPlayAppKeyIos = '2820a4965';
const kBannerAdUnitIos = '4cafh3jwdbyn6ohp';
// Other iOS ad units (not used in the UI yet):
const kInterstitialAdUnitIos = 'hu149fj6h72r1ebj';
const kNativeAdUnitIos = 'ypo41rpcpf7pvcnq';
const kRewardedAdUnitIos = 'mn5ikgnzdo1xdlgh';

// Ad on/off switches. false = no request is sent at all (saves requests when
// a format has low fill). Change, rebuild, release.
const kEnableNativeAd = false; // Native ad in History (low fill, so off)
const kEnableMrecAd = true; // 300x250 MREC in History

// Link added to shared result images.
const kShareLink =
    'https://play.google.com/store/apps/details?id=com.albonik.speedtest';

// Drawer links. Items with a YOUR_... value are hidden (except the privacy link).
const kContactEmail = 'YOUR_EMAIL';
const kAppStoreUrl = 'YOUR_APP_STORE_URL';
const kMoreAppsUrlAndroid =
    'https://play.google.com/store/apps/dev?id=5662539472191775885';
const kMoreAppsUrlIos = 'YOUR_APP_STORE_DEVELOPER_PAGE_URL';

bool isPlaceholder(String s) => s.startsWith('YOUR_') || s.contains('YOUR_DOMAIN');
