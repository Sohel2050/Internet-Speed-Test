import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ads.dart';
import 'app_drawer.dart';
import 'app_info.dart';
import 'config.dart';
import 'consent.dart';
import 'engines.dart';
import 'fullscreen_ads.dart';
import 'history.dart';
import 'insights.dart';
import 'models.dart';
import 'review.dart';
import 'share_card.dart';
import 'sites.dart';
import 'theme_controller.dart';
import 'theme.dart';
import 'update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAppInfo();
  await ThemeController.instance.load();
  runApp(const SpeedApp());
}

class SpeedApp extends StatefulWidget {
  const SpeedApp({super.key});
  @override
  State<SpeedApp> createState() => _SpeedAppState();
}

class _SpeedAppState extends State<SpeedApp> with WidgetsBindingObserver {
  Brightness get _brightness {
    final m = ThemeController.instance.mode;
    if (m == ThemeMode.light) return Brightness.light;
    if (m == ThemeMode.dark) return Brightness.dark;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeController.instance.addListener(_changed);
    applyPalette(_brightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeController.instance.removeListener(_changed);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _changed();

  void _changed() {
    applyPalette(_brightness);
    if (!mounted) return;
    setState(() {});
    // Colours are read from the palette (not from Theme), so force every
    // widget to rebuild once after the theme switched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
  }

  @override
  Widget build(BuildContext context) {
    applyPalette(_brightness);
    final light = isLightPalette;
    SystemChrome.setSystemUIOverlayStyle(light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light);
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      themeMode: light ? ThemeMode.light : ThemeMode.dark,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.light(primary: kLime),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.dark(primary: kLime),
      ),
      home: const UpdateGate(child: SpeedPage()),
    );
  }
}

enum EngineKind { cloudflare, mlab }

class SpeedPage extends StatefulWidget {
  const SpeedPage({super.key});
  @override
  State<SpeedPage> createState() => _SpeedPageState();
}

class _SpeedPageState extends State<SpeedPage> {
  Phase phase = Phase.idle;
  EngineKind kind = EngineKind.cloudflare;
  double live = 0, down = 0, up = 0, ping = 0, jitter = 0;
  String network = '';
  String server = '--';
  String? error;
  bool _mlabConsent = false;
  double plan = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _adShownThisRun = false;
  int _lastData = 0;
  SpeedEngine? _engine;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAds());
  }

  Future<void> _startAds() async {
    if (!AdsService.instance.configured) return;
    await ConsentService.instance.ensureDecision(context);
    await AdsService.instance.init();
  }

  @override
  void dispose() {
    _engine?.cancel();
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _mlabConsent = p.getBool('mlab_consent') ?? false;
    plan = await HistoryStore.loadPlan();
    final e = p.getString('engine');
    _set(() => kind = e == 'mlab' && _mlabConsent
        ? EngineKind.mlab
        : EngineKind.cloudflare);
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<bool> _askConsent() async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTile,
        title: const Text('M-Lab speed test'),
        content: const Text(
            "This test uses Measurement Lab (M-Lab) servers. M-Lab publishes "
            "test results as open data, and they can include your IP address. "
            "By continuing you agree to M-Lab's data policy and our privacy policy."),
        actions: [
          TextButton(
              onPressed: () => _openUrl(kMlabPolicyUrl),
              child: const Text('M-Lab policy')),
          TextButton(
              onPressed: () => _openUrl(kPrivacyUrl),
              child: const Text('Our policy')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kLime, foregroundColor: kOnLime),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I agree'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _mlabConsent = true;
      final p = await SharedPreferences.getInstance();
      await p.setBool('mlab_consent', true);
      return true;
    }
    return false;
  }

  Future<void> _pick(EngineKind k) async {
    if (k == kind) return;
    if (k == EngineKind.mlab && !_mlabConsent && !await _askConsent()) return;
    _set(() => kind = k);
    final p = await SharedPreferences.getInstance();
    await p.setString('engine', k == EngineKind.mlab ? 'mlab' : 'cloudflare');
  }

  Future<void> _detectNetwork() async {
    final r = await Connectivity().checkConnectivity();
    if (r.contains(ConnectivityResult.wifi)) {
      network = 'Wi-Fi';
    } else if (r.contains(ConnectivityResult.mobile)) {
      network = 'Mobile data';
    } else if (r.contains(ConnectivityResult.ethernet)) {
      network = 'Ethernet';
    } else {
      network = 'No connection';
    }
  }

  IconData get _netIcon {
    switch (network) {
      case 'Mobile data':
        return Icons.signal_cellular_alt;
      case 'Ethernet':
        return Icons.settings_ethernet;
      case 'No connection':
        return Icons.signal_wifi_off;
      default:
        return Icons.wifi;
    }
  }

  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _runTest();
    } finally {
      _starting = false;
    }
  }

  Future<void> _runTest() async {
    if (kind == EngineKind.mlab && !_mlabConsent && !await _askConsent()) return;
    _adShownThisRun = await InterstitialManager.instance.maybeShow();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    final engine =
        kind == EngineKind.mlab ? MlabEngine() : CloudflareEngine();
    _engine = engine;
    _set(() {
      phase = Phase.ping;
      live = down = up = ping = jitter = 0;
      server = '--';
      error = null;
      _lastData = 0;
    });
    try {
      await _detectNetwork();
      _set(() {});
      await engine.run(EngineEvents(
        onPhase: (p) => _set(() {
          phase = p;
          live = 0;
        }),
        onLive: (v) => _set(() => live = v),
        onServer: (s) => _set(() => server = s),
        onPing: (p, j) => _set(() {
          ping = p;
          jitter = j;
        }),
        onDownload: (v) => _set(() {
          down = v;
          live = 0;
        }),
        onUpload: (v) => _set(() => up = v),
      ));
      if (engine.cancelled) return;
      HapticFeedback.mediumImpact();
      _set(() {
        phase = Phase.done;
        live = 0;
      });
      final used = engine.downBytes + engine.upBytes;
      _set(() => _lastData = used);
      await HistoryStore.addUsage(used);
      await HistoryStore.add(TestRecord(
        time: DateTime.now(),
        network: network,
        engine: kind == EngineKind.mlab ? 'M-Lab' : 'Cloudflare',
        server: server,
        down: down,
        up: up,
        ping: ping,
        jitter: jitter,
        dataBytes: used,
      ));
      if (!_adShownThisRun) _maybeAskReview();
    } catch (_) {
      _set(() {
        phase = Phase.idle;
        live = 0;
        error = 'Test failed. Check your internet or try the other engine.';
      });
    }
  }

  Future<void> _editPlan() async {
    final controller =
        TextEditingController(text: plan > 0 ? fmtMbps(plan) : '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTile,
        title: const Text('Your plan speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  suffixText: 'Mbps', hintText: 'e.g. 50'),
            ),
            const SizedBox(height: 10),
            Text(
                'Use megabits per second (Mbps) as written on your plan. 50 Mbps is about 6 MB/s.',
                style: TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
        actions: [
          if (plan > 0)
            TextButton(
                onPressed: () => Navigator.pop(ctx, 0.0),
                child: const Text('Remove')),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kLime, foregroundColor: kOnLime),
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(controller.text.trim().replaceAll(',', '.'))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await HistoryStore.savePlan(result);
    _set(() => plan = result < 0 ? 0 : result);
  }

  Future<void> _maybeAskReview() async {
    final good = down >= 10 || (plan > 0 && down >= plan * 0.7);
    if (!good) return;
    final count = (await HistoryStore.load()).length;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await ReviewPrompt.maybeAsk(testCount: count);
  }

  void _openShare() {
    showDialog<void>(
      context: context,
      builder: (_) => ShareCardDialog(
        record: TestRecord(
          time: DateTime.now(),
          network: network,
          engine: kind == EngineKind.mlab ? 'M-Lab' : 'Cloudflare',
          server: server,
          down: down,
          up: up,
          ping: ping,
          jitter: jitter,
        ),
      ),
    );
  }

  double _frac(double v) => (log(1 + v) / log(1 + 1000)).clamp(0.0, 1.0);

  String get _label {
    switch (phase) {
      case Phase.idle:
        return 'Tap start to test';
      case Phase.ping:
        return kind == EngineKind.mlab
            ? 'Finding best server...'
            : 'Checking ping...';
      case Phase.download:
        return 'Testing download...';
      case Phase.upload:
        return 'Testing upload...';
      case Phase.done:
        return 'Result';
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = phase == Phase.ping ||
        phase == Phase.download ||
        phase == Phase.upload;
    final big = phase == Phase.done ? down : live;
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(pageContext: context),
      bottomNavigationBar: const SafeArea(child: BannerAdBox()),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          children: [
            _header(),
            const SizedBox(height: 10),
            _engineSwitch(running),
            const SizedBox(height: 8),
            SizedBox(
              height: (MediaQuery.of(context).size.height * 0.26)
                  .clamp(180.0, 250.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _frac(big)),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, f, _) => CustomPaint(
                  painter: GaugePainter(f),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(big.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w500,
                                  color: kText)),
                          Text('Mbps',
                              style: TextStyle(fontSize: 16, color: kMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _speedRow(),
            const SizedBox(height: 12),
            Row(children: [
              _tile('Ping', ping == 0 ? '--' : '${ping.round()} ms'),
              const SizedBox(width: 12),
              _tile('Jitter', jitter == 0 ? '--' : '${jitter.round()} ms'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.public, color: kMuted, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text('Connected server: $server',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kMuted, fontSize: 15)),
              ),
            ]),
            if (network == 'Mobile data')
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('This test uses mobile data.',
                    style: TextStyle(color: kMuted, fontSize: 13)),
              ),
            if (phase == Phase.done && _lastData > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.data_usage, size: 16, color: kMuted),
                  const SizedBox(width: 6),
                  Text('Data used by this test: ${fmtBytes(_lastData)}',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                ]),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 16),
            PlanCard(
              plan: plan,
              down: down,
              showResult: phase == Phase.done,
              onEdit: _editPlan,
            ),
            if (phase == Phase.done) ...[
              const SizedBox(height: 12),
              InsightsCard(down: down, up: up, ping: ping, jitter: jitter),
            ],
            const SizedBox(height: 12),
            SiteLatencyCard(enabled: !running),
          ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(_label,
                  style: TextStyle(
                      color: running ? kLime : kMuted, fontSize: 14)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kLime,
                        disabledBackgroundColor: kLimeDisabled,
                        foregroundColor: kOnLime,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: running ? null : _start,
                      child: Text(
                        running
                            ? 'Testing...'
                            : (phase == Phase.done ? 'Test again' : 'Start'),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                if (phase == Phase.done) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: BorderSide(color: kLime),
                        foregroundColor: kLime,
                      ),
                      onPressed: _openShare,
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text('Share',
                          style: TextStyle(fontSize: 17)),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(color: kTile, shape: BoxShape.circle),
              child: const Icon(Icons.menu, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Text('Speed test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          const Spacer(),
          if (network.isNotEmpty)
            Flexible(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_netIcon, size: 18, color: kMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(network,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kMuted, fontSize: 14)),
                ),
              ]),
            ),
          IconButton(
            tooltip: 'History',
            icon: Icon(Icons.history, color: kMuted),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
        ],
      );

  Widget _engineSwitch(bool running) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: kTile, borderRadius: BorderRadius.circular(999)),
        child: Row(children: [
          _pill('Cloudflare', kind == EngineKind.cloudflare,
              running ? null : () => _pick(EngineKind.cloudflare)),
          _pill('M-Lab', kind == EngineKind.mlab,
              running ? null : () => _pick(EngineKind.mlab)),
        ]),
      );

  Widget _pill(String t, bool selected, VoidCallback? onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? kLime : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(t,
                  style: TextStyle(
                    color: selected ? kOnLime : kMuted,
                    fontWeight: FontWeight.w500,
                  )),
            ),
          ),
        ),
      );

  Widget _speedRow() => Container(
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: kLine)),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(
                child:
                    _speedCell('Download', down, Icons.arrow_downward, kLime)),
            VerticalDivider(width: 1, color: kLine),
            Expanded(
                child: _speedCell('Upload', up, Icons.arrow_upward, kOrange)),
          ]),
        ),
      );

  Widget _speedCell(String t, double v, IconData i, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, size: 18, color: c),
            const SizedBox(width: 6),
            Text(t, style: TextStyle(color: c, fontSize: 17)),
          ]),
          const SizedBox(height: 6),
          Text(v == 0 ? '--' : v.toStringAsFixed(1),
              style:
                  const TextStyle(fontSize: 36, fontWeight: FontWeight.w500)),
          Text('Mbps', style: TextStyle(color: kMuted, fontSize: 15)),
        ]),
      );

  Widget _tile(String t, String v) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
              color: kTile, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: TextStyle(color: kMuted, fontSize: 15)),
              const SizedBox(height: 4),
              Text(v,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

class GaugePainter extends CustomPainter {
  final double fraction;
  GaugePainter(this.fraction);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = 135 * pi / 180;
    const sweep = 270 * pi / 180;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = kTrack;
    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = kLime;
    canvas.drawArc(rect, start, sweep, false, track);
    if (fraction > 0.005) {
      canvas.drawArc(rect, start, sweep * fraction, false, bar);
    }
  }

  @override
  bool shouldRepaint(GaugePainter old) => old.fraction != fraction;
}
