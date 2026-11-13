# Climate

App Flutter de previsão do tempo para qualquer cidade. Cruza ECMWF, ICON e GFS (Open-Meteo),
mostra média, faixa entre modelos, probabilidade de chuva (ensemble de 122 membros) e
um selo de confiança **na previsão de chuva**. Spec original: `SPEC_app_previsao_ipupiara (1).md`.

## Cidades
- A aba **Cidades** pesquisa qualquer cidade (Open-Meteo Geocoding) e gerencia a lista.
- Uma cidade pode ser **favorita** (estrela): é a que aparece quando o app abre.
- Tocar numa cidade da lista mostra a previsão dela nas abas Hoje, 15 dias e Mapa.
- Primeira execução: só Ipupiara-BA, já favorita.
- Avisos do INMET só aparecem para cidades brasileiras (o código IBGE é resolvido ao adicionar).

## Rodar
    flutter pub get
    flutter run            # Android/iOS (o mapa Windy usa WebView, só Android/iOS)
    flutter test           # testes de domínio, dados, cidades + smoke de UI
    dart run tool/live_check.dart [cidade]   # confere o pipeline contra as APIs reais

## Ajustes rápidos (`lib/core/constants.dart`)
- `rainThresholdMm` — limiar de chuva (1 mm; teste 2 mm se o ECMWF inflar a probabilidade)
- `pesosModelos` — pesos por modelo
- `uncertainProbLow/High` — faixa de probabilidade que rebaixa a confiança (30%–70%)

## Confiança
Só considera a chuva: modelos concordando sobre haver ou não chuva = alta; divergindo = baixa;
probabilidade entre 30% e 70% rebaixa um nível; dias sem todos os modelos ficam limitados a média.

## Estrutura
- `lib/domain` — Dart puro: cidade, agregação, ensemble, confiança
- `lib/data` — HTTP (previsão, geocoding), DTOs (parse defensivo por regex), cache offline por cidade (30 min), lista de cidades
- `lib/presentation` — telas (Hoje, 15 dias, Cidades, Mapa, Sobre, detalhe do dia)

Dados meteorológicos: Open-Meteo.com (uso não comercial). Avisos: INMET. Satélite: CPTEC/INPE.
