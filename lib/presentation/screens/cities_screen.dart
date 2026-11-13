import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/geocoding_api.dart';
import '../../domain/city.dart';
import '../cities_controller.dart';
import '../widgets/common.dart';

/// Aba Cidades: pesquisa qualquer cidade e gerencia as já adicionadas
/// (favoritar uma, remover, escolher qual mostrar).
class CitiesScreen extends StatefulWidget {
  const CitiesScreen({super.key, this.onCityOpened});

  /// Chamado quando o usuário escolhe uma cidade para ver a previsão.
  final VoidCallback? onCityOpened;

  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

enum _SearchState { idle, loading, done, error }

class _CitiesScreenState extends State<CitiesScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  _SearchState _state = _SearchState.idle;
  List<City> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.length < 2) {
      _requestId++; // descarta resposta em andamento
      setState(() {
        _state = _SearchState.idle;
        _results = const [];
      });
      return;
    }
    setState(() => _state = _SearchState.loading);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_requestId;
    try {
      final found = await context.read<GeocodingApi>().search(q);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = found;
        _state = _SearchState.done;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _state = _SearchState.error;
      });
    }
  }

  void _clear() {
    _debounce?.cancel();
    _requestId++;
    _field.clear();
    setState(() {
      _state = _SearchState.idle;
      _results = const [];
    });
  }

  Future<void> _add(City city) async {
    final cities = context.read<CitiesController>();
    final messenger = ScaffoldMessenger.of(context);
    final added = await cities.add(city);
    if (!mounted) return;
    _clear();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added
                ? '${city.name} adicionada.'
                : '${city.name} já está na sua lista.',
          ),
        ),
      );
  }

  Future<void> _confirmRemove(City city) async {
    final cities = context.read<CitiesController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover ${city.name}?'),
        content: const Text('A cidade sai da sua lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) await cities.remove(city);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cities = context.watch<CitiesController>();
    final searching = _field.text.trim().length >= 2;

    return SafeArea(
      bottom: false,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Cidades',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _field,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Pesquisar cidade',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _field.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Limpar',
                      onPressed: _clear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (searching)
            ..._buildResults(context, cities)
          else
            ..._buildSaved(context, cities),
        ],
      ),
    );
  }

  List<Widget> _buildResults(BuildContext context, CitiesController cities) {
    final theme = Theme.of(context);
    switch (_state) {
      case _SearchState.idle:
      case _SearchState.loading:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ];
      case _SearchState.error:
        return [
          ErrorState(
            message: 'Não foi possível pesquisar. Verifique sua conexão.',
            onRetry: () => _search(_field.text.trim()),
          ),
        ];
      case _SearchState.done:
        if (_results.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nenhuma cidade encontrada.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          const SectionLabel('Resultados'),
          for (final city in _results)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                key: ValueKey('result-${city.id}'),
                leading: const Icon(Icons.place_outlined),
                title: Text(city.name),
                subtitle: city.regionLabel.isEmpty
                    ? null
                    : Text(city.regionLabel),
                trailing: cities.contains(city)
                    ? Text(
                        'Já adicionada',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                onTap: () => _add(city),
              ),
            ),
        ];
    }
  }

  List<Widget> _buildSaved(BuildContext context, CitiesController cities) {
    final theme = Theme.of(context);
    return [
      const SectionLabel('Minhas cidades'),
      for (final city in cities.cities)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            key: ValueKey('city-${city.id}'),
            selected: cities.isActive(city),
            selectedTileColor: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.35,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            leading: Icon(
              cities.isActive(city) ? Icons.place : Icons.place_outlined,
            ),
            title: Text(city.name),
            subtitle: Text(
              [
                if (city.regionLabel.isNotEmpty) city.regionLabel,
                if (cities.isFavorite(city)) 'Abre ao iniciar',
              ].join(' · '),
            ),
            onTap: () {
              cities.select(city);
              widget.onCityOpened?.call();
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: cities.isFavorite(city)
                      ? 'Cidade favorita'
                      : 'Tornar favorita',
                  icon: Icon(
                    cities.isFavorite(city) ? Icons.star : Icons.star_border,
                    color: cities.isFavorite(city)
                        ? Colors.amber.shade700
                        : null,
                  ),
                  onPressed: () => cities.setFavorite(city),
                ),
                IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: cities.canRemove
                      ? () => _confirmRemove(city)
                      : null,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        'A cidade com a estrela é a que aparece quando o app abre.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}
