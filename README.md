# Clima Ipupiara

App Flutter de previsão do tempo para Ipupiara-BA. Cruza ECMWF, ICON e GFS (Open-Meteo),
mostra média, faixa entre modelos, probabilidade de chuva (ensemble de 122 membros) e
um selo de confiança. Spec original: `SPEC_app_previsao_ipupiara (1).md`.

## Rodar
    flutter pub get
    flutter run            # Android/iOS (o mapa Windy usa WebView, só Android/iOS)
    flutter test           # testes de domínio + smoke de UI
    dart run tool/live_check.dart   # confere o pipeline contra as APIs reais

## Ajustes rápidos (`lib/core/constants.dart`)
- `rainThresholdMm` — limiar de chuva (1 mm; teste 2 mm se o ECMWF inflar a probabilidade)
- `pesosModelos` — pesos por modelo
- limiares de confiança (`tempSpreadHigh`, `tempSpreadMedium`, `uncertainProb*`)

## Estrutura
- `lib/domain` — Dart puro: agregação, ensemble, confiança
- `lib/data` — HTTP, DTOs (parse defensivo por regex), cache offline (30 min)
- `lib/presentation` — telas (Hoje, 15 dias, detalhe, Mapa, Sobre)

Dados meteorológicos: Open-Meteo.com (uso não comercial). Avisos: INMET. Satélite: CPTEC/INPE.
