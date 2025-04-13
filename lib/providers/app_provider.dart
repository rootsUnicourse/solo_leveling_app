import 'package:flutter/material.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/models/user.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

class AppProvider extends ChangeNotifier {
  User? _user;
  List<Mission> _todayMissions = [];
  bool _isLoading = true;

  User? get user => _user;
  List<Mission> get todayMissions => _todayMissions;
  bool get isLoading => _isLoading;

  // Initialize the provider
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load user and missions
      await _loadUser();
      await _loadTodayMissions();
    } catch (e) {
      debugPrint('Error initializing app: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load user from storage
  Future<void> _loadUser() async {
    _user = await StorageService.getUser();
    notifyListeners();
  }

  // Load today's missions from storage
  Future<void> _loadTodayMissions() async {
    _todayMissions = await StorageService.getTodayMissions();
    notifyListeners();
  }

  // Add a new mission
  Future<void> addMission({
    required String name,
    required String description,
    required int xp,
    required MissionType type,
  }) async {
    final mission = Mission(
      id: const Uuid().v4(),
      name: name,
      description: description,
      xp: xp,
      type: type,
      createdAt: DateTime.now(),
    );

    // Save mission to storage
    await StorageService.saveMission(mission);
    
    // Reload missions from storage to ensure consistency
    await _loadTodayMissions();
    
    // Debug
    debugPrint('Added mission: ${mission.name}, total missions: ${_todayMissions.length}');
  }

  // Complete a mission
  Future<void> completeMission(String missionId) async {
    await StorageService.completeMission(missionId);
    
    // Reload user and missions to reflect changes
    await _loadUser();
    await _loadTodayMissions();
  }

  // Get the appropriate mission type icon
  IconData getMissionTypeIcon(MissionType type) {
    switch (type) {
      case MissionType.strength:
        return Icons.fitness_center;
      case MissionType.intelligence:
        return Icons.psychology;
      case MissionType.discipline:
        return Icons.schedule;
      case MissionType.willpower:
        return Icons.bolt;
      case MissionType.agility:
        return Icons.directions_run;
      case MissionType.endurance:
        return Icons.battery_full;
      default:
        return Icons.star;
    }
  }

  // Get the color for a mission type
  Color getMissionTypeColor(MissionType type) {
    switch (type) {
      case MissionType.strength:
        return Colors.red;
      case MissionType.intelligence:
        return Colors.blue;
      case MissionType.discipline:
        return Colors.purple;
      case MissionType.willpower:
        return Colors.amber;
      case MissionType.agility:
        return Colors.green;
      case MissionType.endurance:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
} 