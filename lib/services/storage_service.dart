import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/models/user.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const String userBoxName = 'userBox';
  static const String missionsBoxName = 'missionsBox';
  static const String currentUserKey = 'currentUser';
  
  static bool _initialized = false;

  // Initialize Hive and register adapters
  static Future<void> init() async {
    // Prevent double initialization
    if (_initialized) {
      debugPrint('StorageService already initialized, skipping');
      return;
    }
    
    try {
      debugPrint('StorageService: Beginning initialization');
      final appDocumentDir = await getApplicationDocumentsDirectory();
      String path = appDocumentDir.path;
      debugPrint('StorageService: Using path $path');
      
      // Don't re-initialize Hive if it's already initialized
      try {
        await Hive.initFlutter(path);
        debugPrint('StorageService: Hive initialized at $path');
      } catch (e) {
        debugPrint('StorageService: Hive already initialized: $e');
      }
      
      // Ensure boxes are open, but don't open them twice
      if (!Hive.isBoxOpen(userBoxName)) {
        await Hive.openBox<User>(userBoxName);
        debugPrint('StorageService: Opened userBox');
      }
      
      if (!Hive.isBoxOpen(missionsBoxName)) {
        await Hive.openBox<Mission>(missionsBoxName);
        debugPrint('StorageService: Opened missionsBox');
      }
      
      _initialized = true;
      debugPrint('StorageService: initialization complete!');
    } catch (e, stack) {
      debugPrint('Error in StorageService.init: $e');
      debugPrint('Stack trace: $stack');
      
      // Attempt recovery
      try {
        debugPrint('StorageService: Attempting recovery...');
        await Hive.deleteFromDisk();
        await Hive.initFlutter();
          
        await Hive.openBox<User>(userBoxName);
        await Hive.openBox<Mission>(missionsBoxName);
        
        // Create an initial user if needed
        final box = Hive.box<User>(userBoxName);
        if (!box.containsKey(currentUserKey)) {
          await box.put(currentUserKey, User.initial());
        }
        
        _initialized = true;
        debugPrint('StorageService: Recovery successful!');
      } catch (e) {
        debugPrint('StorageService: Recovery failed: $e');
        rethrow;
      }
    }
  }

  // User methods
  static Box<User> _getUserBox() {
    try {
      if (!_initialized) {
        throw Exception('StorageService not initialized');
      }
      return Hive.box<User>(userBoxName);
    } catch (e) {
      debugPrint('Error getting user box: $e');
      throw Exception('Failed to access user data');
    }
  }

  static Future<User> getUser() async {
    try {
      final box = _getUserBox();
      User? user = box.get(currentUserKey);
      
      if (user == null) {
        debugPrint('No user found, creating initial user');
        user = User.initial();
        await box.put(currentUserKey, user);
      }
      
      return user;
    } catch (e) {
      debugPrint('Error in getUser: $e');
      // Create a new user if we can't get the existing one
      final user = User.initial();
      try {
        await _getUserBox().put(currentUserKey, user);
      } catch (_) {
        // Ignore error on fallback
      }
      return user;
    }
  }

  static Future<void> saveUser(User user) async {
    try {
      final box = _getUserBox();
      await box.put(currentUserKey, user);
    } catch (e) {
      debugPrint('Error saving user: $e');
      // Allow error to propagate
      rethrow;
    }
  }

  // Mission methods
  static Box<Mission> _getMissionsBox() {
    try {
      if (!_initialized) {
        throw Exception('StorageService not initialized');
      }
      return Hive.box<Mission>(missionsBoxName);
    } catch (e) {
      debugPrint('Error getting missions box: $e');
      throw Exception('Failed to access missions data');
    }
  }

  static Future<List<Mission>> getTodayMissions() async {
    try {
      final box = _getMissionsBox();
      
      // Safety check for corrupted data
      if (box.isEmpty) {
        debugPrint('Missions box is empty');
        return [];
      }
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Debug: Print all missions in the box
      debugPrint('All missions: ${box.values.length}');
      for (var mission in box.values) {
        debugPrint('Mission: ${mission.name}, Date: ${mission.createdAt}, ID: ${mission.id}');
      }
      
      // Filter missions with date validation
      final List<Mission> todayMissions = [];
      for (var mission in box.values) {
        try {
          if (mission.createdAt.isAfter(startOfDay.subtract(const Duration(minutes: 1))) && 
              mission.createdAt.isBefore(endOfDay)) {
            todayMissions.add(mission);
          }
        } catch (e) {
          debugPrint('Error processing mission: $e');
          // Skip this mission if it has invalid date
        }
      }
      
      // Debug: Print today's missions
      debugPrint('Today missions: ${todayMissions.length}');
      
      return todayMissions;
    } catch (e) {
      debugPrint('Error getting today missions: $e');
      // Return empty list on error
      return [];
    }
  }

  static Future<void> saveMission(Mission mission) async {
    try {
      final box = _getMissionsBox();
      await box.put(mission.id, mission);
    } catch (e) {
      debugPrint('Error saving mission: $e');
      rethrow;
    }
  }

  static Future<void> completeMission(String missionId) async {
    try {
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
    } catch (e) {
      debugPrint('Error completing mission: $e');
      // Allow error to propagate
      rethrow;
    }
  }
  
  // Reset app data (for troubleshooting)
  static Future<void> resetAllData() async {
    try {
      debugPrint('Resetting all app data...');
      await Hive.deleteBoxFromDisk(userBoxName);
      await Hive.deleteBoxFromDisk(missionsBoxName);
      
      _initialized = false;
      
      // Reinitialize
      await init();
      
      // Create initial user
      final user = User.initial();
      await _getUserBox().put(currentUserKey, user);
      debugPrint('App data reset successfully');
    } catch (e) {
      debugPrint('Error resetting app data: $e');
      rethrow;
    }
  }
} 