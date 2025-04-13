import 'package:hive/hive.dart';

part 'mission.g.dart';

enum MissionType {
  strength,
  intelligence,
  discipline,
  willpower,
  agility,
  endurance
}

@HiveType(typeId: 0)
class Mission {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int xp;

  @HiveField(4)
  final MissionType type;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  bool isCompleted;

  Mission({
    required this.id,
    required this.name,
    required this.description,
    required this.xp,
    required this.type,
    required this.createdAt,
    this.isCompleted = false,
  });

  Mission copyWith({
    String? id,
    String? name,
    String? description,
    int? xp,
    MissionType? type,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return Mission(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      xp: xp ?? this.xp,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
} 