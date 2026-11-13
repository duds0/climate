import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants.dart';
import '../../domain/city.dart';
import '../cities_controller.dart';
import '../widgets/common.dart';

/// Aba Mapa: radar/nuvens do Windy (WebView) e satélite GOES-19 do CPTEC/INPE.
/// Apenas exibição; nenhuma interpretação automática.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final city = context.select<CitiesController, City>((c) => c.active);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mapa · ${city.name}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Chuva e nuvens'),
                        icon: Icon(Icons.public),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Satélite'),
                        icon: Icon(Icons.satellite_alt_outlined),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                // Nova chave = novo WebView centrado na cidade escolhida.
                _WindyView(key: ValueKey(city.id), city: city),
                _SatelliteView(city: city),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Windy (WebView)
// ---------------------------------------------------------------------------

bool get _webViewSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class _WindyView extends StatefulWidget {
  const _WindyView({super.key, required this.city});
  final City city;

  @override
  State<_WindyView> createState() => _WindyViewState();
}

class _WindyViewState extends State<_WindyView>
    with AutomaticKeepAliveClientMixin {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  Uri get _windyUri => Uri.parse(
    AppConstants.windyUrl(widget.city.latitude, widget.city.longitude),
  );

  @override
  void initState() {
    super.initState();
    if (_webViewSupported) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) =>
                mounted ? setState(() => _loading = false) : null,
            onWebResourceError: (e) {
              if (e.isForMainFrame ?? true) {
                if (mounted) setState(() => _failed = true);
              }
            },
          ),
        )
        ..loadRequest(_windyUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_controller == null || _failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.public_off_outlined,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                _failed
                    ? 'Não foi possível carregar o mapa. Verifique a conexão.'
                    : 'O mapa embutido só está disponível no Android e no iOS.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: () =>
                    launchUrl(_windyUri, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir no navegador'),
              ),
              if (_failed) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _failed = false;
                      _loading = true;
                    });
                    _controller?.reload();
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller!),
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Satélite CPTEC/INPE (GOES-19, canal 13 – infravermelho)
// ---------------------------------------------------------------------------

class _SatelliteView extends StatefulWidget {
  const _SatelliteView({required this.city});
  final City city;

  @override
  State<_SatelliteView> createState() => _SatelliteViewState();
}

class _SatelliteViewState extends State<_SatelliteView>
    with AutomaticKeepAliveClientMixin {
  // A imagem é uma projeção equirretangular (2192 x 2320 px): longitude de
  // 115°W a 25°W e latitude de 35°N a 55°S, calibradas pela grade da própria
  // imagem (medidas na versão reduzida de 1876 x 1986 px).
  static const _aspect = 2192 / 2320;
  static const _refW = 1876.0;
  static const _refH = 1986.0;
  static const _plotLeft = 40.0;
  static const _plotTop = 85.0;
  static const _plotW = 1822.0; // 90° de longitude
  static const _plotH = 1800.0; // 90° de latitude

  /// Posição da cidade na imagem (fração de largura/altura); null se estiver
  /// fora da área coberta.
  ({double x, double y})? get _marker {
    final lat = widget.city.latitude;
    final lon = widget.city.longitude;
    if (lon < -115 || lon > -25 || lat > 35 || lat < -55) return null;
    return (
      x: (_plotLeft + (lon + 115) * _plotW / 90) / _refW,
      y: (_plotTop + (35 - lat) * _plotH / 90) / _refH,
    );
  }

  @override
  void didUpdateWidget(covariant _SatelliteView old) {
    super.didUpdateWidget(old);
    if (old.city.id != widget.city.id) _transformInit = false;
  }

  final _transform = TransformationController();
  bool _transformInit = false;

  Future<({String url, DateTime utc})?>? _latest;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _latest = _findLatest();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// O CPTEC não tem uma URL fixa de "última imagem": os arquivos são
  /// `S11161213_AAAAMMDDHHMM.jpg` (UTC, a cada 10 min). Procuramos a mais
  /// recente voltando de 10 em 10 min até encontrar uma que exista.
  Future<({String url, DateTime utc})?> _findLatest() async {
    final now = DateTime.now().toUtc();
    var t = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute - now.minute % 10,
    );
    final client = http.Client();
    try {
      for (var i = 0; i < 18; i++) {
        final url = _urlFor(t);
        try {
          final res = await client
              .head(Uri.parse(url))
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) return (url: url, utc: t);
        } on TimeoutException {
          return null;
        } catch (_) {
          // tenta o próximo
        }
        t = t.subtract(const Duration(minutes: 10));
      }
    } finally {
      client.close();
    }
    return null;
  }

  String _urlFor(DateTime utc) {
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    final stamp =
        '${utc.year}${p(utc.month)}${p(utc.day)}${p(utc.hour)}${p(utc.minute)}';
    return '${AppConstants.satelliteBase}/${utc.year}/${p(utc.month)}/S11161213_$stamp.jpg';
  }

  void _retry() => setState(() {
    _transformInit = false;
    _latest = _findLatest();
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return FutureBuilder(
      future: _latest,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }
        final latest = snap.data;
        if (latest == null) {
          return ErrorState(
            message: 'Não foi possível carregar a imagem de satélite.',
            onRetry: _retry,
          );
        }
        final local = latest.utc.toLocal();
        final marker = _marker;
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: Colors.black,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // Mostra a imagem em "cover" e centraliza na cidade.
                        final viewW = box.maxWidth;
                        final viewH = box.maxHeight;
                        final imgW = viewW;
                        final imgH = imgW / _aspect;
                        if (!_transformInit) {
                          final zoom = marker == null ? 1.0 : 2.6;
                          final mx = marker?.x ?? 0.5;
                          final my = marker?.y ?? 0.5;
                          final dx = viewW / 2 - mx * imgW * zoom;
                          final dy = viewH / 2 - my * imgH * zoom;
                          _transform.value = Matrix4.identity()
                            ..translateByDouble(dx, dy, 0, 1)
                            ..scaleByDouble(zoom, zoom, 1, 1);
                          _transformInit = true;
                        }
                        return InteractiveViewer(
                          transformationController: _transform,
                          minScale: 0.6,
                          maxScale: 8,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(400),
                          child: SizedBox(
                            width: imgW,
                            height: imgH,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.network(
                                    latest.url,
                                    fit: BoxFit.fill,
                                    loadingBuilder:
                                        (context, child, progress) =>
                                            progress == null
                                            ? child
                                            : const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                    ),
                                              ),
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                                if (marker != null)
                                  Positioned(
                                    left: marker.x * imgW - 9,
                                    top: marker.y * imgH - 9,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'GOES-19 · canal 13 (infravermelho) · $hh:$mm (horário local)\n'
                      'Nuvens mais frias (azul/verde/vermelho) indicam topos altos e chuva forte. '
                      'Pinça para aproximar. Fonte: CPTEC/INPE.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
