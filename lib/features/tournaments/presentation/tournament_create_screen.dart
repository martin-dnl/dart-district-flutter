import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../controller/tournament_controller.dart';
import '../data/tournament_service.dart';

class TournamentCreateScreen extends ConsumerStatefulWidget {
  const TournamentCreateScreen({super.key});

  @override
  ConsumerState<TournamentCreateScreen> createState() =>
      _TournamentCreateScreenState();
}

class _TournamentCreateScreenState
    extends ConsumerState<TournamentCreateScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '0');

  String _mode = '501';
  String _finish = 'double_out';
  String _format = 'single_elimination';
  int _maxPlayers = 16;
  int _poolCount = 4;
  int _qualifiedPerPool = 2;
  int _legsPool = 3;
  int _setsPool = 1;
  int _legsBracket = 5;
  int _setsBracket = 1;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 7));
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _cityCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (pickedTime == null) return;

    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du tournoi est obligatoire.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(tournamentServiceProvider).createTournament({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'mode': _mode,
        'finish': _finish,
        'max_players': _maxPlayers,
        'format': _format,
        if (_format == 'pools_then_elimination') ...{
          'pool_count': _poolCount,
          'qualified_per_pool': _qualifiedPerPool,
          'legs_per_set_pool': _legsPool,
          'sets_to_win_pool': _setsPool,
        },
        'legs_per_set_bracket': _legsBracket,
        'sets_to_win_bracket': _setsBracket,
        'venue_name': _venueCtrl.text.trim().isEmpty
            ? null
            : _venueCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'entry_fee': double.tryParse(_feeCtrl.text.trim()) ?? 0,
        'scheduled_at': _scheduledAt.toIso8601String(),
      });

      if (!mounted) return;
      ref.invalidate(tournamentsListProvider);
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creation du tournoi impossible.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creer un tournoi'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_nameCtrl, 'Nom', required: true),
          const SizedBox(height: 12),
          _field(_descCtrl, 'Description', maxLines: 3),
          const SizedBox(height: 12),
          _segment(
            label: 'Mode',
            value: _mode,
            options: const ['301', '501', '701', 'cricket'],
            onChanged: (value) => setState(() => _mode = value),
          ),
          const SizedBox(height: 12),
          _segment(
            label: 'Finish',
            value: _finish,
            options: const ['double_out', 'single_out', 'master_out'],
            onChanged: (value) => setState(() => _finish = value),
          ),
          const SizedBox(height: 12),
          _segment(
            label: 'Max joueurs',
            value: _maxPlayers.toString(),
            options: const ['4', '8', '16', '32'],
            onChanged: (value) =>
                setState(() => _maxPlayers = int.parse(value)),
          ),
          const SizedBox(height: 12),
          _segment(
            label: 'Format',
            value: _format,
            options: const ['single_elimination', 'pools_then_elimination'],
            labels: const {
              'single_elimination': 'Elimination directe',
              'pools_then_elimination': 'Poules + Elimination',
            },
            onChanged: (value) => setState(() => _format = value),
          ),
          if (_format == 'pools_then_elimination') ...[
            const SizedBox(height: 12),
            _counter(
              'Nombre de poules',
              _poolCount,
              min: 2,
              max: 8,
              onChanged: (v) => setState(() => _poolCount = v),
            ),
            const SizedBox(height: 8),
            _counter(
              'Qualifies par poule',
              _qualifiedPerPool,
              min: 1,
              max: 4,
              onChanged: (v) => setState(() => _qualifiedPerPool = v),
            ),
            const SizedBox(height: 8),
            _counter(
              'Legs par set (poules)',
              _legsPool,
              min: 1,
              max: 9,
              onChanged: (v) => setState(() => _legsPool = v),
            ),
            const SizedBox(height: 8),
            _counter(
              'Sets pour gagner (poules)',
              _setsPool,
              min: 1,
              max: 5,
              onChanged: (v) => setState(() => _setsPool = v),
            ),
          ],
          const SizedBox(height: 12),
          _counter(
            'Legs par set (bracket)',
            _legsBracket,
            min: 1,
            max: 11,
            onChanged: (v) => setState(() => _legsBracket = v),
          ),
          const SizedBox(height: 8),
          _counter(
            'Sets pour gagner (bracket)',
            _setsBracket,
            min: 1,
            max: 5,
            onChanged: (v) => setState(() => _setsBracket = v),
          ),
          const SizedBox(height: 12),
          _field(_venueCtrl, 'Lieu'),
          const SizedBox(height: 12),
          _field(_cityCtrl, 'Ville'),
          const SizedBox(height: 12),
          _field(
            _feeCtrl,
            'Frais inscription (EUR)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Date et heure',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: Text(
              _formatDate(_scheduledAt),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(
              Icons.calendar_today,
              color: AppColors.primary,
            ),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              minimumSize: const Size(double.infinity, 52),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Creer'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _segment({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    Map<String, String>? labels,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  label: Text(labels?[option] ?? option),
                  selected: value == option,
                  onSelected: (_) => onChanged(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _counter(
    String label,
    int value, {
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Text(
              value.toString(),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year a $hour:$minute';
  }
}
