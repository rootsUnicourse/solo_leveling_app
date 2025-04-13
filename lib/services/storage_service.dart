import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/models/user.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const String userBoxName = 'userBox';
  static const String missionsBoxName = 'missionsBox';
  static const String currentUserKey = 'currentUser';

  // Initialize Hive and register adapters
  static Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    
    // We're using the manually created adapters in main.dart
    // until code generation is properly set up
    
    // Open boxes
    await Hive.openBox<User>(userBoxName);
    await Hive.openBox<Mission>(missionsBoxName);
  }

  // User methods
  static Box<User> _getUserBox() {
    return Hive.box<User>(userBoxName);
  }

  static Future<User> getUser() async {
    final box = _getUserBox();
    User? user = box.get(currentUserKey);
    
    if (user == null) {
      user = User.initial();
      await box.put(currentUserKey, user);
    }
    
    return user;
  }

  static Future<void> saveUser(User user) async {
    final box = _getUserBox();
    await box.put(currentUserKey, user);
  }

  // Mission methods
  static Box<Mission> _getMissionsBox() {
    return Hive.box<Mission>(missionsBoxName);
  }

  static Future<List<Mission>> getTodayMissions() async {
    final box = _getMissionsBox();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    // Debug: Print all missions in the box
    debugPrint('All missions: ${box.values.length}');
    for (var mission in box.values) {
      debugPrint('Mission: ${mission.name}, Date: ${mission.createdAt}, ID: ${mission.id}');
    }
    
    final todayMissions = box.values
        .where((mission) => 
            mission.createdAt.isAfter(startOfDay.subtract(const Duration(minutes: 1))) && 
            mission.createdAt.isBefore(endOfDay))
        .toList();
    
    // Debug: Print today's missions
    debugPrint('Today missions: ${todayMissions.length}');
    
    return todayMissions;
  }

  static Future<void> saveMission(Mission mission) async {
    final box = _getMissionsBox();
    await box.put(mission.id, mission);
  }

  static Future<void> completeMission(String missionId) async {
    final box = _getMissionsBox();
    final mission = box.get(missionId);
    
    if (mission != null) {
      mission.isCompleted = true;
      await box.put(missionId, mission);
      
      // Update user stats
      final user = await getUser();
      user.addXp(mission.xp);
      user.addStatPoints(mission.type.toString().split('.').last, mission.xp);
      await saveUser(user);
    }
  }
} 