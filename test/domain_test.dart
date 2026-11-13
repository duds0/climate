import 'dart:convert';
import 'dart:io';

import 'package:clima_ipupiara/data/dto.dart';
import 'package:clima_ipupiara/domain/aggregation.dart';
import 'package:clima_ipupiara/domain/confidence.dart';
import 'package:clima_ipupiara/domain/ensemble_aggregator.dart';
import 'package:clima_ipupiara/domain/inputs.dart';
import 'package:clima_ipupiara/domain/models.dart';
import 'package:clima_ipupiara/domain/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

ModelDay md(
  String m, {
  double? max,
  double? min,
  double? precip,
  double? wind,
  int? code,
}) => ModelDay(
  model: m,
  tMax: max,
  tMin: min,
  precip: precip,
  wind: wind,
  weatherCode: code,
);

final day = DateTime(2026, 11, 10);

void main() {
  group('temperatura', () {
    test('média com 3 modelos', () {
      final d = buildDay(
        date: day,
        models: [
          md('a', max: 30, min: 20),
          md('b', max: 32, min: 22),
          md('c', max: 31, min: 21),
        ],
      );
      expect(d.tMax, closeTo(31, 1e-9));
      expect(d.tMin, closeTo(21, 1e-9));
      expect(d.tMaxRange!.min, 30);
      expect(d.tMaxRange!.max, 32);
    });

    test('média com 2 modelos (um null)', () {
      final d = buildDay(
        date: day,
        models: [
          md('a', max: 30, min: 20),
          md('b'), // tudo null
          md('c', max: 32, min: 22),
        ],
      );
      expect(d.tMax, closeTo(31, 1e-9));
      expect(d.tMin, closeTo(21, 1e-9));
      expect(d.models.length, 2);
    });

    test('pesos desiguais mudam a média', () {
      final d = buildDay(
        date: day,
        models: [md('a', max: 30), md('b', max: 36)],
        weights: {'a': 1, 'b': 2},
      );
      expect(d.tMax, closeTo(34, 1e-9));
    });
  });

  group('chuva', () {
    test('modelos com 0, 0 e 20 mm', () {
      final d = buildDay(
        date: day,
        models: [
          md('a', max: 30, min: 20, precip: 0),
          md('b', max: 30, min: 20, precip: 0),
          md('c', max: 30, min: 20, precip: 20),
        ],
      );
      expect(d.precipMean, closeTo(6.67, 0.01));
      expect(d.modelsWithRain, 1);
      expect(d.modelsWithPrecipData, 3);
      expect(d.precipRange!.min, 0);
      expect(d.precipRange!.max, 20);
      expect(d.confidence.level, Confidence.baixa);
    });

    test(
      'fallback sem ensemble usa modelosComChuva/disponíveis e marca estimativa',
      () {
        final d = buildDay(
          date: day,
          models: [md('a', precip: 0), md('b', precip: 5), md('c', precip: 6)],
        );
        expect(d.probabilityIsEstimate, isTrue);
        expect(d.rainProbability, closeTo(2 / 3, 1e-9));
        expect(d.ensemble, isNull);
      },
    );

    test('probabilidade >= 60% troca o ícone para chuva', () {
      final ens = EnsembleDay(
        date: '2026-11-10',
        total: 50,
        withRain: 40,
        byModel: const {},
      );
      final d = buildDay(
        date: day,
        ensembleDay: ens,
        models: [md('a', code: 3), md('b', code: 3), md('c', code: 3)],
      );
      expect(d.iconFromProbability, isTrue);
      expect(d.weatherCode, 61);
      expect(d.probabilityIsEstimate, isFalse);
    });

    test('ícone mais frequente entre os modelos', () {
      final d = buildDay(
        date: day,
        models: [md('a', code: 3), md('b', code: 3), md('c', code: 61)],
      );
      expect(d.weatherCode, 3);
    });
  });

  group('ensemble', () {
    test('30 de 50 membros acima do limiar -> 60%', () {
      final members = [
        for (var i = 0; i < 50; i++) [i < 30 ? 2.0 : 0.2],
      ];
      final r = aggregateEnsemble(
        EnsembleInput(times: ['2026-11-10T00:00'], members: {'x': members}),
        thresholdMm: 1.0,
      );
      expect(r['2026-11-10']!.probability, closeTo(0.6, 1e-9));
      expect(r['2026-11-10']!.byModel['x']!.members, 50);
    });

    test('10 x 0,1 mm conta como 1 mm (sem erro de ponto flutuante)', () {
      final series = List<double?>.filled(10, 0.1);
      final r = aggregateEnsemble(
        EnsembleInput(
          times: [for (var h = 0; h < 10; h++) '2026-11-10T0$h:00'],
          members: {
            'x': [series],
          },
        ),
        thresholdMm: 1.0,
      );
      expect(r['2026-11-10']!.withRain, 1);
    });

    test('virada de dia: 23h e 00h caem em dias diferentes', () {
      final r = aggregateEnsemble(
        const EnsembleInput(
          times: [
            '2026-11-10T22:00',
            '2026-11-10T23:00',
            '2026-11-11T00:00',
            '2026-11-11T01:00',
          ],
          members: {
            'x': [
              [0.0, 0.6, 0.6, 0.0], // 0,6 em cada dia: nenhum passa de 1 mm
              [0.0, 0.6, 0.6, 0.6], // dia 11 soma 1,2
            ],
          },
        ),
        thresholdMm: 1.0,
      );
      expect(r['2026-11-10']!.withRain, 0);
      expect(r['2026-11-11']!.withRain, 1);
    });

    test('membro totalmente null no dia é ignorado', () {
      final r = aggregateEnsemble(
        const EnsembleInput(
          times: ['2026-11-10T00:00'],
          members: {
            'x': [
              [null],
              [2.0],
            ],
          },
        ),
        thresholdMm: 1.0,
      );
      expect(r['2026-11-10']!.total, 1);
      expect(r['2026-11-10']!.probability, 1.0);
    });

    test('localDateKey respeita o fuso na virada do dia (UTC-3)', () {
      const utc3 = Duration(hours: -3);
      expect(
        localDateKey(DateTime.utc(2026, 11, 11, 2), utc3),
        '2026-11-10',
      ); // 23h locais
      expect(
        localDateKey(DateTime.utc(2026, 11, 11, 3), utc3),
        '2026-11-11',
      ); // 00h locais
    });

    test('localDateKey com outros fusos (UTC-5 e UTC+9)', () {
      const utc5 = Duration(hours: -5);
      const tokyo = Duration(hours: 9);
      expect(localDateKey(DateTime.utc(2026, 11, 11, 4), utc5), '2026-11-10');
      expect(localDateKey(DateTime.utc(2026, 11, 11, 5), utc5), '2026-11-11');
      expect(localDateKey(DateTime.utc(2026, 11, 10, 15), tokyo), '2026-11-11');
      expect(wallClock(DateTime.utc(2026, 11, 10, 15), tokyo).hour, 0);
    });

    test(
      'parse das chaves: agrupa por sufixo e inclui o controle (51/40/31)',
      () {
        Map<String, dynamic> hourly = {
          'time': ['2026-11-10T00:00'],
        };
        void add(String suffix, int n) {
          hourly['precipitation_$suffix'] = [0.0]; // controle
          for (var i = 1; i <= n; i++) {
            hourly['precipitation_member${i.toString().padLeft(2, '0')}_$suffix'] =
                [0.0];
          }
        }

        add('ecmwf_ifs025_ensemble', 50);
        add('icon_seamless_eps', 39);
        add('ncep_gefs025', 30);
        final input = EnsembleDto.parse({'hourly': hourly});
        expect(input.members['ecmwf_ifs025_ensemble']!.length, 51);
        expect(input.members['icon_seamless_eps']!.length, 40);
        expect(input.members['ncep_gefs025']!.length, 31);
        expect(input.totalMembers, 122);
      },
    );

    test('JSON real do ensemble: 122 membros e probabilidade plausível', () {
      final json =
          jsonDecode(File('test/fixtures/ensemble.json').readAsStringSync())
              as Map<String, dynamic>;
      final input = EnsembleDto.parse(json);
      expect(input.totalMembers, 122);
      final r = aggregateEnsemble(input, thresholdMm: 1.0);
      expect(r.length, 7);
      for (final d in r.values) {
        expect(d.total, 122);
        expect(d.probability, inInclusiveRange(0, 1));
      }
    });
  });

  group('confiança (só chuva)', () {
    ConfidenceResult c({int wr = 0, int rm = 3, double? p}) =>
        assessConfidence(modelsWithRain: wr, rainModels: rm, probability: p);

    test('chuva: todos concordam = alta; divergem = baixa', () {
      expect(c(wr: 0, p: 0.1).level, Confidence.alta);
      expect(c(wr: 3, p: 0.95).level, Confidence.alta);
      expect(c(wr: 1, p: 0.9).level, Confidence.baixa);
    });

    test('probabilidade entre 30% e 70% (inclusive) rebaixa um nível', () {
      expect(c(wr: 0, p: 0.30).level, Confidence.media);
      expect(c(wr: 0, p: 0.70).level, Confidence.media);
      expect(c(wr: 0, p: 0.29).level, Confidence.alta);
      expect(c(wr: 0, p: 0.71).level, Confidence.alta);
    });

    test('um único modelo nunca é "alta"', () {
      final r = c(wr: 0, rm: 1, p: 0);
      expect(r.level, Confidence.baixa);
      expect(r.singleModel, isTrue);
    });

    test('temperatura divergente não afeta a confiança', () {
      final day = DateTime(2026, 11, 10);
      final d = buildDay(
        date: day,
        models: [
          md('a', max: 25, min: 15, precip: 0),
          md('b', max: 35, min: 25, precip: 0), // 10 °C de diferença
          md('c', max: 30, min: 20, precip: 0),
        ],
      );
      expect(d.confidence.level, Confidence.alta);
    });
  });

  group('JSON real do forecast', () {
    test('relatório completo com 7 dias, 3 modelos e 24 h', () {
      final fJson =
          jsonDecode(File('test/fixtures/forecast.json').readAsStringSync())
              as Map<String, dynamic>;
      final eJson =
          jsonDecode(File('test/fixtures/ensemble.json').readAsStringSync())
              as Map<String, dynamic>;
      final forecast = ForecastDto.parse(fJson);
      expect(forecast.dailyByModel.keys.toSet(), {
        'ecmwf_ifs025',
        'icon_seamless',
        'gfs_seamless',
      });

      final report = buildReport(
        forecast: forecast,
        ensemble: EnsembleDto.parse(eJson),
        nowInstant: DateTime.utc(2026, 11, 10, 16), // 13h em Bahia
      );
      expect(report.days.length, 7);
      expect(report.days.first.models.length, 3);
      expect(report.hours.length, 24);
      expect(report.hours.first.time, DateTime(2026, 11, 10, 13));
      expect(report.ensembleAvailable, isTrue);
      expect(report.days.first.tMax, closeTo((29.6 + 30.3 + 29.7) / 3, 1e-9));
      expect(report.current!.temperature, 28.3);
    });

    test('sem ensemble usa fallback', () {
      final fJson =
          jsonDecode(File('test/fixtures/forecast.json').readAsStringSync())
              as Map<String, dynamic>;
      final report = buildReport(
        forecast: ForecastDto.parse(fJson),
        nowInstant: DateTime.utc(2026, 11, 10, 16),
      );
      expect(report.ensembleAvailable, isFalse);
      expect(report.days.every((d) => d.probabilityIsEstimate), isTrue);
    });

    test('valores null em um modelo são ignorados', () {
      final fJson =
          jsonDecode(File('test/fixtures/forecast.json').readAsStringSync())
              as Map<String, dynamic>;
      (fJson['daily'] as Map)['temperature_2m_max_gfs_seamless'][6] = null;
      final report = buildReport(
        forecast: ForecastDto.parse(fJson),
        nowInstant: DateTime.utc(2026, 11, 10, 16),
      );
      expect(report.days.last.tMax, closeTo((27.7 + 27.3) / 2, 1e-9));
    });
  });

  group('15 dias (cobertura desigual dos modelos)', () {
    final fJson =
        jsonDecode(File('test/fixtures/forecast15.json').readAsStringSync())
            as Map<String, dynamic>;
    final eJson =
        jsonDecode(File('test/fixtures/ensemble15.json').readAsStringSync())
            as Map<String, dynamic>;

    test('gera 15 dias; ICON some depois do 7º e o ensemble encolhe', () {
      final report = buildReport(
        forecast: ForecastDto.parse(fJson),
        ensemble: EnsembleDto.parse(eJson),
        nowInstant: DateTime.utc(2026, 11, 10, 16),
      );
      expect(report.days.length, 15);
      expect(report.days[0].models.length, 3);
      expect(report.days[6].models.length, 3);
      expect(report.days[7].models.length, 2); // sem ICON
      // Ensemble: 122 membros até o dia 8, 82 (ECMWF+GEFS) até o 11, só ECMWF (51) depois.
      expect(report.days[0].ensemble!.total, 122);
      expect(report.days[7].ensemble!.total, 122);
      expect(report.days[8].ensemble!.total, 82);
      expect(report.days[10].ensemble!.total, 82);
      expect(report.days[11].ensemble!.total, 51);
      expect(report.days[14].ensemble!.total, 51);
      for (final d in report.days) {
        expect(d.tMax != null || d.precipMean != null, isTrue);
        expect(d.rainProbability, inInclusiveRange(0, 1));
      }
    });

    test('dia 15: temperatura máxima do ECMWF é null e o app não quebra', () {
      final report = buildReport(
        forecast: ForecastDto.parse(fJson),
        ensemble: EnsembleDto.parse(eJson),
        nowInstant: DateTime.utc(2026, 11, 10, 16),
      );
      final last = report.days.last;
      // Só o GFS cobre o último dia: a confiança nunca é "alta".
      expect(last.confidence.level, isNot(Confidence.alta));
      expect(last.tMax, isNotNull);
    });

    test('menos modelos que o esperado limita a confiança a "média"', () {
      final models = [
        md('a', max: 30, min: 20, precip: 0),
        md('b', max: 30, min: 20, precip: 0),
      ];
      final full = buildDay(date: day, models: models);
      expect(full.confidence.level, Confidence.alta); // sem teto

      final capped = buildDay(date: day, models: models, expectedModels: 3);
      expect(capped.confidence.level, Confidence.media);
      expect(capped.confidence.limitedByCoverage, isTrue);
    });

    test('relatório de 15 dias nunca dá "alta" nos dias sem o ICON', () {
      final report = buildReport(
        forecast: ForecastDto.parse(fJson),
        ensemble: EnsembleDto.parse(eJson),
        nowInstant: DateTime.utc(2026, 11, 10, 16),
      );
      for (final d in report.days.skip(7)) {
        expect(d.confidence.level, isNot(Confidence.alta));
      }
    });

    test('empate de ícone: sem chuva provável prefere o tempo brando', () {
      final soft = buildDay(
        date: day,
        ensembleDay: EnsembleDay(
          date: '2026-11-17',
          total: 100,
          withRain: 10,
          byModel: const {},
        ),
        models: [md('a', code: 3), md('b', code: 80)],
      );
      expect(soft.weatherCode, 3);
      final wet = buildDay(
        date: day,
        ensembleDay: EnsembleDay(
          date: '2026-11-17',
          total: 100,
          withRain: 55,
          byModel: const {},
        ),
        models: [md('a', code: 3), md('b', code: 80)],
      );
      expect(wet.weatherCode, 80);
    });
  });

  group('INMET', () {
    test('filtra por código IBGE e ignora formatos inesperados', () {
      final alerts = InmetDto.parse({
        'hoje': [
          {
            'id_aviso': 1,
            'descricao': 'Acumulado de Chuva',
            'severidade': 'Perigo Potencial',
            'aviso_cor': '#FFFE00',
            'geocodes': '2900801,2914109',
            'inicio': '2026-11-10 00:01',
            'fim': '2026-11-13 23:59',
            'riscos': ['x'],
            'instrucoes': ['y'],
          },
          {'id_aviso': 2, 'descricao': 'Outro', 'geocodes': '2900801'},
        ],
        'futuro': [
          {
            'id_aviso': 1,
            'descricao': 'Acumulado de Chuva',
            'geocodes': '2914109',
          },
        ],
      }, ibgeCode: '2914109');
      expect(alerts.length, 1); // deduplicado por id
      expect(alerts.first.title, 'Acumulado de Chuva');
      expect(InmetDto.parse('lixo', ibgeCode: '2914109'), isEmpty);
      expect(InmetDto.parse(null, ibgeCode: '2914109'), isEmpty);
    });
  });
}
