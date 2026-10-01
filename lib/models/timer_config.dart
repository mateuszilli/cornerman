import 'dart:convert';

class TimerConfig {
  final int rounds;
  final int roundSeconds;
  final int restSeconds;
  final int prepSeconds;
  final int warningSeconds;
  final bool countdownBeeps;
  final bool haptics;
  final bool keepScreenAwake;
  final double volume;
  final bool muted;
  final bool duckAudio;

  const TimerConfig({
    required this.rounds,
    required this.roundSeconds,
    required this.restSeconds,
    required this.prepSeconds,
    required this.warningSeconds,
    required this.countdownBeeps,
    required this.haptics,
    required this.keepScreenAwake,
    required this.volume,
    required this.muted,
    required this.duckAudio,
  });

  static const TimerConfig championship = TimerConfig(
    rounds: 12,
    roundSeconds: 180,
    restSeconds: 60,
    prepSeconds: 10,
    warningSeconds: 10,
    countdownBeeps: true,
    haptics: true,
    keepScreenAwake: true,
    volume: 1.0,
    muted: false,
    duckAudio: true,
  );

  static const TimerConfig pro = TimerConfig(
    rounds: 10,
    roundSeconds: 180,
    restSeconds: 60,
    prepSeconds: 10,
    warningSeconds: 10,
    countdownBeeps: true,
    haptics: true,
    keepScreenAwake: true,
    volume: 1.0,
    muted: false,
    duckAudio: true,
  );

  static const TimerConfig training = TimerConfig(
    rounds: 3,
    roundSeconds: 180,
    restSeconds: 60,
    prepSeconds: 10,
    warningSeconds: 10,
    countdownBeeps: true,
    haptics: true,
    keepScreenAwake: true,
    volume: 1.0,
    muted: false,
    duckAudio: true,
  );

  static const List<({String name, TimerConfig config})> builtinPresets = [
    (name: 'Championship (12×3/1)', config: championship),
    (name: 'Pro (10×3/1)', config: pro),
    (name: 'Training (3×3/1)', config: training),
  ];

  TimerConfig copyWith({
    int? rounds,
    int? roundSeconds,
    int? restSeconds,
    int? prepSeconds,
    int? warningSeconds,
    bool? countdownBeeps,
    bool? haptics,
    bool? keepScreenAwake,
    double? volume,
    bool? muted,
    bool? duckAudio,
  }) {
    return TimerConfig(
      rounds: rounds ?? this.rounds,
      roundSeconds: roundSeconds ?? this.roundSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      prepSeconds: prepSeconds ?? this.prepSeconds,
      warningSeconds: warningSeconds ?? this.warningSeconds,
      countdownBeeps: countdownBeeps ?? this.countdownBeeps,
      haptics: haptics ?? this.haptics,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      duckAudio: duckAudio ?? this.duckAudio,
    );
  }

  Map<String, dynamic> toJson() => {
        'rounds': rounds,
        'roundSeconds': roundSeconds,
        'restSeconds': restSeconds,
        'prepSeconds': prepSeconds,
        'warningSeconds': warningSeconds,
        'countdownBeeps': countdownBeeps,
        'haptics': haptics,
        'keepScreenAwake': keepScreenAwake,
        'volume': volume,
        'muted': muted,
        'duckAudio': duckAudio,
      };

  factory TimerConfig.fromJson(Map<String, dynamic> j) => TimerConfig(
        rounds: j['rounds'] as int,
        roundSeconds: j['roundSeconds'] as int,
        restSeconds: j['restSeconds'] as int,
        prepSeconds: j['prepSeconds'] as int,
        warningSeconds: j['warningSeconds'] as int,
        countdownBeeps: j['countdownBeeps'] as bool,
        haptics: j['haptics'] as bool,
        keepScreenAwake: j['keepScreenAwake'] as bool,
        volume: (j['volume'] as num).toDouble(),
        muted: j['muted'] as bool,
        // Absent in configs persisted before this field existed.
        duckAudio: j['duckAudio'] as bool? ?? true,
      );

  String toJsonString() => jsonEncode(toJson());

  factory TimerConfig.fromJsonString(String s) =>
      TimerConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class NamedPreset {
  final String name;
  final TimerConfig config;
  const NamedPreset({required this.name, required this.config});

  Map<String, dynamic> toJson() => {'name': name, 'config': config.toJson()};

  factory NamedPreset.fromJson(Map<String, dynamic> j) => NamedPreset(
        name: j['name'] as String,
        config: TimerConfig.fromJson(j['config'] as Map<String, dynamic>),
      );
}
