import 'package:flutter/material.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/models/user.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'package:solo_leveling_app/widgets/mission_complete_effect.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

class AppProvider extends ChangeNotifier {
  User? _user;
  List<Mission> _activeMissions = [];
  List<Mission> _completedMissions = [];
  List<Mission> _dailyMissions = [];
  bool _isLoading = true;

  User? get user => _user;
  List<Mission> get activeMissions => _activeMissions;
  List<Mission> get completedMissions => _completedMissions;
  List<Mission> get dailyMissions => _dailyMissions;
  bool get isLoading => _isLoading;

  // Initialize the provider
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try to initialize StorageService
      try {
        await StorageService.init();
      } catch (e) {
        debugPrint('Storage service init failed: $e');
        // Continue with fallbacks
      }
      
      // Load user with fallback
      try {
        await _loadUser();
      } catch (e) {
        debugPrint('User loading failed: $e');
        _user = User.initial();
      }
      
      // Load missions with fallback
      try {
        await _loadAllMissions();
        await _loadDailyMissions();
      } catch (e) {
        debugPrint('Missions loading failed: $e');
        _activeMissions = [];
        _completedMissions = [];
        _dailyMissions = [];
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      // Ensure we have at least default values
      _user = _user ?? User.initial();
      _activeMissions = _activeMissions.isNotEmpty ? _activeMissions : [];
      _completedMissions = _completedMissions.isNotEmpty ? _completedMissions : [];
      _dailyMissions = _dailyMissions.isNotEmpty ? _dailyMissions : [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load user from storage
  Future<void> _loadUser() async {
    _user = await StorageService.getUser();
    notifyListeners();
  }

  // Load all missions from storage and separate active and completed
  Future<void> _loadAllMissions() async {
    final allMissions = await StorageService.getTodayMissions();
    
    // Sort by date, newest first
    allMissions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Separate active and completed missions
    // Daily missions should only appear in the dailyMissions list, not in activeMissions
    _activeMissions = allMissions.where((mission) => !mission.isCompleted && !mission.isDaily).toList();
    _completedMissions = allMissions.where((mission) => mission.isCompleted && !mission.isDaily).toList();
    
    notifyListeners();
  }
  
  // Load daily missions
  Future<void> _loadDailyMissions() async {
    _dailyMissions = await StorageService.getDailyMissions();
    notifyListeners();
  }

  // Add a new mission
  Future<void> addMission({
    required String name,
    required String description,
    required int xp,
    required MissionType type,
    bool isDaily = false,
  }) async {
    final mission = Mission(
      id: const Uuid().v4(),
      name: name,
      description: description,
      xp: xp,
      type: type,
      createdAt: DateTime.now(),
      isDaily: isDaily,
    );

    // Save mission to storage
    await StorageService.saveMission(mission);
    
    // Reload missions from storage to ensure consistency
    await _loadAllMissions();
    await _loadDailyMissions();
    
    // Debug
    debugPrint('Added mission: ${mission.name}, isDaily: $isDaily, total active missions: ${_activeMissions.length}');
  }

  // Complete a mission
  Future<void> completeMission(String missionId, [BuildContext? context]) async {
    try {
      // Find the mission first to get its details
      final mission = _activeMissions.firstWhere(
        (m) => m.id == missionId,
        orElse: () => throw Exception('Mission not found'),
      );
      
      // First complete the mission in storage
      await StorageService.completeMission(missionId);
      
      // Show completion effect if context is provided and valid
      if (context != null) {
        try {
          // Only show the effect if the context is still mounted
          if (ModalRoute.of(context) != null && ModalRoute.of(context)!.isCurrent) {
            final statType = mission.type.toString().split('.').last;
            final statColor = getMissionTypeColor(mission.type);
            
            // Show the completion effect
            MissionCompleteEffect.show(
              context,
              mission.xp,
              statType,
              statColor,
            );
          }
        } catch (e) {
          debugPrint('Error showing mission completion effect: $e');
          // Continue with user data updates even if effect fails
        }
      }
      
      // Reload user and missions to reflect changes
      await _loadUser();
      await _loadAllMissions();
    } catch (e) {
      debugPrint('Error in completeMission: $e');
      
      // Try to complete mission without showing effects
      try {
        await StorageService.completeMission(missionId);
        await _loadUser();
        await _loadAllMissions();
      } catch (innerError) {
        debugPrint('Secondary error in completeMission: $innerError');
        rethrow;
      }
    }
  }

  // Directly complete a quick mission from popup
  Future<void> completeQuickMission(Mission mission, BuildContext? context) async {
    try {
      // First save the mission
      await StorageService.saveMission(mission);
      
      // Then complete it - but only show effects if context is valid
      if (context != null && ModalRoute.of(context) != null && ModalRoute.of(context)!.isCurrent) {
        await completeMission(mission.id, context);
      } else {
        // Complete without visual effects
        await completeMission(mission.id);
      }
    } catch (e) {
      debugPrint('Error completing quick mission: $e');
      // Try minimal completion approach
      try {
        await StorageService.completeMission(mission.id);
        await _loadUser();
        await _loadAllMissions();
      } catch (_) {}
    }
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