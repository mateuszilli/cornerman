import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/timer_config.dart';
import '../services/audio_service.dart';
import '../services/prefs_service.dart';
import '../state/locale_notifier.dart';
import '../state/timer_notifier.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  late TimerConfig _cfg;
  List<NamedPreset> _userPresets = [];

  @override
  void initState() {
    super.initState();
    _cfg = ref.read(timerProvider).config;
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final p = await ref.read(prefsServiceProvider).loadUserPresets();
    if (mounted) setState(() => _userPresets = p);
  }

  Future<void> _applyAndPop() async {
    await ref.read(prefsServiceProvider).saveConfig(_cfg);
    ref.read(timerProvider.notifier).loadConfig(_cfg);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveAsPreset() async {
    final name = await _promptName(context);
    if (name == null || name.isEmpty) return;
    final preset = NamedPreset(name: name, config: _cfg);
    final updated = [..._userPresets, preset];
    await ref.read(prefsServiceProvider).saveUserPresets(updated);
    if (mounted) setState(() => _userPresets = updated);
  }

  Future<void> _deleteUserPreset(int index) async {
    final updated = [..._userPresets]..removeAt(index);
    await ref.read(prefsServiceProvider).saveUserPresets(updated);
    if (mounted) setState(() => _userPresets = updated);
  }

  void _applyPreset(TimerConfig c) => setState(() => _cfg = c);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.settingsTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _applyAndPop,
            child: Text(l10n.buttonDone,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _Section(l10n.sectionPresets, children: [
            _PresetGrid(
              builtins: TimerConfig.builtinPresets,
              userPresets: _userPresets,
              current: _cfg,
              onSelect: _applyPreset,
              onDelete: _deleteUserPreset,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saveAsPreset,
              icon: const Icon(Icons.save_alt_rounded, color: Colors.white70),
              label: Text(l10n.saveAsPreset,
                  style: const TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24)),
            ),
          ]),
          _Section(l10n.sectionRounds, children: [
            _Stepper(
              label: l10n.numberOfRounds,
              value: _cfg.rounds,
              min: 1,
              max: 20,
              onChanged: (v) => setState(() => _cfg = _cfg.copyWith(rounds: v)),
            ),
          ]),
          _Section(l10n.sectionDurations, children: [
            _TimeStepper(
              label: l10n.roundDuration,
              totalSeconds: _cfg.roundSeconds,
              min: 30,
              max: 600,
              step: 30,
              onChanged: (v) =>
                  setState(() => _cfg = _cfg.copyWith(roundSeconds: v)),
            ),
            _TimeStepper(
              label: l10n.restDuration,
              totalSeconds: _cfg.restSeconds,
              min: 0,
              max: 300,
              step: 15,
              onChanged: (v) =>
                  setState(() => _cfg = _cfg.copyWith(restSeconds: v)),
            ),
            _TimeStepper(
              label: l10n.prepDuration,
              totalSeconds: _cfg.prepSeconds,
              min: 0,
              max: 60,
              step: 5,
              onChanged: (v) =>
                  setState(() => _cfg = _cfg.copyWith(prepSeconds: v)),
            ),
            _TimeStepper(
              label: l10n.warningLead,
              totalSeconds: _cfg.warningSeconds,
              min: 5,
              max: 30,
              step: 5,
              onChanged: (v) =>
                  setState(() => _cfg = _cfg.copyWith(warningSeconds: v)),
            ),
          ]),
          _Section(l10n.sectionAudio, children: [
            _SliderRow(
              label: l10n.volume,
              value: _cfg.volume,
              onChanged: (v) {
                setState(() => _cfg = _cfg.copyWith(volume: v));
                ref.read(audioServiceProvider).setVolume(v);
              },
            ),
            _Toggle(
              label: l10n.mute,
              value: _cfg.muted,
              onChanged: (v) {
                setState(() => _cfg = _cfg.copyWith(muted: v));
                ref.read(audioServiceProvider).setMuted(v);
              },
            ),
            _Toggle(
              label: l10n.countdownBeeps,
              value: _cfg.countdownBeeps,
              onChanged: (v) =>
                  setState(() => _cfg = _cfg.copyWith(countdownBeeps: v)),
            ),
          ]),
          _Section(l10n.sectionDevice, children: [
            _Toggle(
              label: l10n.keepScreenAwake,
              value: _cfg.keepScreenAwake,
              onChanged: (v) =>
                  setState(() => _cfg = _cfg.copyWith(keepScreenAwake: v)),
            ),
            _Toggle(
              label: l10n.hapticFeedback,
              value: _cfg.haptics,
              onChanged: (v) =>
                  setState(() => _cfg = _cfg.copyWith(haptics: v)),
            ),
            _LanguagePicker(systemLabel: l10n.languageSystem),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

Future<String?> _promptName(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(l10n.presetName, style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: l10n.presetNameHint,
          hintStyle: const TextStyle(color: Colors.white38),
          enabledBorder:
              const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel)),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.save)),
      ],
    ),
  );
}

// ── section widget ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, {required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── stepper ────────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
              icon: Icons.remove,
              onTap: value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 42,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
          ),
          _StepBtn(
              icon: Icons.add,
              onTap: value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

// ── time stepper ───────────────────────────────────────────────────────────

class _TimeStepper extends StatelessWidget {
  final String label;
  final int totalSeconds;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _TimeStepper({
    required this.label,
    required this.totalSeconds,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            onTap: totalSeconds > min
                ? () => onChanged((totalSeconds - step).clamp(min, max))
                : null,
          ),
          SizedBox(
            width: 58,
            child: Text(
              _fmt(totalSeconds),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            onTap: totalSeconds < max
                ? () => onChanged((totalSeconds + step).clamp(min, max))
                : null,
          ),
        ],
      ),
    );
  }
}

// ── slider row ─────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      trailing: SizedBox(
        width: 140,
        child: Slider(
          value: value,
          min: 0,
          max: 1,
          activeColor: Colors.white,
          inactiveColor: Colors.white24,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── toggle row ─────────────────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      trailing: Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: Colors.green.shade700,
        onChanged: onChanged,
      ),
    );
  }
}

// ── base row ───────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _Row({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ── language picker ────────────────────────────────────────────────────────

class _LanguagePicker extends ConsumerWidget {
  final String systemLabel;
  const _LanguagePicker({required this.systemLabel});

  static const _options = [
    (code: null, label: ''),      // placeholder; label filled at runtime
    (code: 'en', label: 'English'),
    (code: 'es', label: 'Español'),
    (code: 'pt', label: 'Português'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentCode = ref.watch(localeProvider)?.languageCode;

    String labelFor(String? code) =>
        code == null ? systemLabel : _options.firstWhere((o) => o.code == code).label;

    return _Row(
      label: l10n.language,
      trailing: PopupMenuButton<String?>(
        initialValue: currentCode,
        onSelected: (code) => ref.read(localeProvider.notifier).setLocale(code),
        color: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (_) => [
          _menuItem(null, systemLabel, currentCode),
          _menuItem('en', 'English', currentCode),
          _menuItem('es', 'Español', currentCode),
          _menuItem('pt', 'Português', currentCode),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labelFor(currentCode),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String?> _menuItem(String? code, String label, String? current) {
    final selected = code == current;
    return PopupMenuItem<String?>(
      value: code,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── step button ────────────────────────────────────────────────────────────

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: onTap != null ? Colors.white : Colors.white24),
      onPressed: onTap,
      iconSize: 22,
      splashRadius: 20,
    );
  }
}

// ── preset grid ────────────────────────────────────────────────────────────

class _PresetGrid extends StatelessWidget {
  final List<({String name, TimerConfig config})> builtins;
  final List<NamedPreset> userPresets;
  final TimerConfig current;
  final ValueChanged<TimerConfig> onSelect;
  final ValueChanged<int> onDelete;

  const _PresetGrid({
    required this.builtins,
    required this.userPresets,
    required this.current,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in builtins)
            _PresetChip(
              name: p.name,
              selected: _configsEqual(p.config, current),
              onTap: () => onSelect(p.config),
            ),
          for (int i = 0; i < userPresets.length; i++)
            _PresetChip(
              name: userPresets[i].name,
              selected: _configsEqual(userPresets[i].config, current),
              onTap: () => onSelect(userPresets[i].config),
              onDelete: () => onDelete(i),
            ),
        ],
      ),
    );
  }

  bool _configsEqual(TimerConfig a, TimerConfig b) {
    return a.rounds == b.rounds &&
        a.roundSeconds == b.roundSeconds &&
        a.restSeconds == b.restSeconds &&
        a.prepSeconds == b.prepSeconds;
  }
}

class _PresetChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PresetChip({
    required this.name,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: selected ? Colors.black54 : Colors.white38,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
