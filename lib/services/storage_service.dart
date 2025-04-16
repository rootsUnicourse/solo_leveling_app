import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/models/user.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class StorageService {
  static const String userBoxName = 'userBox';
  static const String missionsBoxName = 'missionsBox';
  static const String currentUserKey = 'currentUser';
  static const String lastResetKey = 'lastDailyReset';
  static const String firstTimeOpenKey = 'firstTimeOpen';
  
  // Keep track of initialization state
  static bool _initialized = false;
  static int _initAttempts = 0;
  static const int maxInitAttempts = 3;

  // Initialize Hive and register adapters
  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    
    try {
      // Verify boxes are open
      if (!Hive.isBoxOpen(userBoxName)) {
        await Hive.openBox<User>(userBoxName);
      }
      
      if (!Hive.isBoxOpen(missionsBoxName)) {
        await Hive.openBox<Mission>(missionsBoxName);
      }
      
      // Ensure user exists
      final box = Hive.box<User>(userBoxName);
      if (box.isEmpty) {
        await box.put(currentUserKey, User.initial());
      }
      
      // Check if we need to reset daily missions
      await _checkAndResetDailyMissions();
      
      _initialized = true;
    } catch (e) {
      debugPrint('Error in StorageService.init: $e');
      // Do not throw, let the app continue even if storage fails
    }
  }
  
  // Check if this is the first time opening the app
  static Future<bool> isFirstTimeOpen() async {
    try {
      await init(); // Make sure storage is initialized
      
      // Use a separate box for first time tracking to avoid conflicts
      if (!Hive.isBoxOpen('settingsBox')) {
        await Hive.openBox('settingsBox');
      }
      
      final settingsBox = Hive.box('settingsBox');
      final isFirstTime = settingsBox.get(firstTimeOpenKey, defaultValue: true) as bool;
      
      return isFirstTime;
    } catch (e) {
      debugPrint('Error checking first time open status: $e');
      return true; // Default to true if there's an error
    }
  }
  
  // Mark app as opened (no longer first time)
  static Future<void> markAppOpened() async {
    try {
      await init(); // Make sure storage is initialized
      
      // Use a separate box for first time tracking to avoid conflicts
      if (!Hive.isBoxOpen('settingsBox')) {
        await Hive.openBox('settingsBox');
      }
      
      final settingsBox = Hive.box('settingsBox');
      await settingsBox.put(firstTimeOpenKey, false);
      
      debugPrint('App marked as opened');
    } catch (e) {
      debugPrint('Error marking app as opened: $e');
    }
  }
  
  // Check if we need to reset daily missions
  static Future<void> _checkAndResetDailyMissions() async {
    try {
      // Use the settings box for tracking reset time
      if (!Hive.isBoxOpen('settingsBox')) {
        await Hive.openBox('settingsBox');
      }
      
      final settingsBox = Hive.box('settingsBox');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get the last reset date
      final lastResetMillis = settingsBox.get(lastResetKey, defaultValue: 0) as int;
      final lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetMillis);
      final lastResetDay = DateTime(lastReset.year, lastReset.month, lastReset.day);
      
      // If last reset was before today, reset daily missions
      if (lastResetDay.isBefore(today)) {
        await _resetDailyMissions();
        // Update the last reset time
        await settingsBox.put(lastResetKey, now.millisecondsSinceEpoch);
        debugPrint('Daily missions reset at ${now.toIso8601String()}');
      }
    } catch (e) {
      debugPrint('Error checking daily missions reset: $e');
    }
  }
  
  // Reset all daily missions
  static Future<void> _resetDailyMissions() async {
    try {
      final box = Hive.box<Mission>(missionsBoxName);
      
      // Get all missions
      final allMissions = box.values.toList();
      
      // Reset completed status for daily missions
      for (var mission in allMissions) {
        if (mission.isDaily && mission.isCompleted) {
          final resetMission = mission.copyWith(
            isCompleted: false,
            // Update the created date to today so it shows in today's missions
            createdAt: DateTime.now(),
          );
          await box.put(mission.id, resetMission);
        }
      }
      debugPrint('Daily missions have been reset');
    } catch (e) {
      debugPrint('Error resetting daily missions: $e');
    }
  }

  // Verify boxes are open and accessible
  static Future<void> _verifyBoxes() async {
    try {
      // Check if boxes are open, otherwise open them
      if (!Hive.isBoxOpen(userBoxName)) {
        await Hive.openBox<User>(userBoxName);
        debugPrint('Opened userBox');
      }
      
      if (!Hive.isBoxOpen(missionsBoxName)) {
        await Hive.openBox<Mission>(missionsBoxName);
        debugPrint('Opened missionsBox');
      }
      
      // Test accessing the boxes
      final userBox = Hive.box<User>(userBoxName);
      final missionsBox = Hive.box<Mission>(missionsBoxName);
      
      // Just log box contents
      debugPrint('User box length: ${userBox.length}');
      debugPrint('Missions box length: ${missionsBox.length}');
      
      debugPrint('Boxes verified successfully');
    } catch (e) {
      debugPrint('Box verification failed: $e');
      throw Exception('Box verification failed');
    }
  }

  // Recovery attempt for initialization failures
  static Future<void> _attemptRecovery() async {
    try {
      // Close all boxes
      await Hive.close();
      
      // Delete box files
      await Hive.deleteBoxFromDisk(userBoxName);
      await Hive.deleteBoxFromDisk(missionsBoxName);
      
      // Reopen boxes
      await Hive.openBox<Mission>(missionsBoxName);
      await Hive.openBox<User>(userBoxName);
      
      // Create initial user
      await _ensureUserExists();
      
      _initialized = true;
      debugPrint('StorageService: Recovery successful!');
    } catch (e) {
      debugPrint('StorageService: Recovery attempt failed: $e');
      _initialized = false;
    }
  }

  // Force reset of all data
  static Future<void> _forceReset() async {
    try {
      debugPrint('StorageService: Forcing complete reset...');
      
      // Close all boxes
      await Hive.close();
      
      // Delete all Hive data
      await Hive.deleteFromDisk();
      
      // Get application directory
      final appDocumentDir = await getApplicationDocumentsDirectory();
      final hivePath = "${appDocumentDir.path}/hive_boxes";
      
      // Delete directory
      final dir = Directory(hivePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      
      // Recreate directory
      await dir.create(recursive: true);
      
      // Reinitialize Hive
      await Hive.initFlutter(hivePath);
      
      // Reset initialization flag
      _initialized = false;
      
      debugPrint('StorageService: Force reset complete');
    } catch (e) {
      debugPrint('StorageService: Force reset failed: $e');
    }
  }

  // Ensure a user exists in the database
  static Future<void> _ensureUserExists() async {
    try {
      final box = Hive.box<User>(userBoxName);
      
      if (!box.containsKey(currentUserKey)) {
        debugPrint('Creating initial user');
        await box.put(currentUserKey, User.initial());
      } else {
        debugPrint('User already exists');
      }
    } catch (e) {
      debugPrint('Error ensuring user exists: $e');
      throw Exception('Failed to ensure user exists');
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
      if (!_initialized) {
        await init();
      }
      
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
        if (Hive.isBoxOpen(userBoxName)) {
          await Hive.box<User>(userBoxName).put(currentUserKey, user);
        } else {
          await init();  // Try to reinitialize
          await Hive.box<User>(userBoxName).put(currentUserKey, user);
        }
      } catch (_) {
        // Ignore error on fallback
      }
      return user;
    }
  }

  static Future<void> saveUser(User user) async {
    try {
      if (!_initialized) {
        await init();
      }
      
      final box = _getUserBox();
      await box.put(currentUserKey, user);
    } catch (e) {
      debugPrint('Error saving user: $e');
      // Try to reinitialize on failure
      await init();
      await Hive.box<User>(userBoxName).put(currentUserKey, user);
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
      if (!_initialized) {
        await init(); // Try to initialize
      }
      
      final box = _getMissionsBox();
      
      // Safety check for corrupted data
      if (box.isEmpty) {
        debugPrint('Missions box is empty');
        return [];
      }
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Get all missions as a list first to avoid potential issues with iterators
      final allMissions = box.values.toList();
      debugPrint('All missions: ${allMissions.length}');
      
      // Filter missions with date validation
      final List<Mission> todayMissions = [];
      for (var mission in allMissions) {
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
      if (!_initialized) {
        await init();
      }
      
      final box = _getMissionsBox();
      await box.put(mission.id, mission);
      debugPrint('Saved mission: ${mission.name}');
    } catch (e) {
      debugPrint('Error saving mission: $e');
      
      // Try simple approach
      try {
        await Hive.box<Mission>(missionsBoxName).put(mission.id, mission);
      } catch (secondError) {
        debugPrint('Second error saving mission: $secondError');
        // Re-initialize and try again
        await init();
        await Hive.box<Mission>(missionsBoxName).put(mission.id, mission);
      }
    }
  }

  static Future<void> completeMission(String missionId) async {
    try {
      if (!_initialized) {
        await init();
      }
      
      final box = _getMissionsBox();
      final mission = box.get(missionId);
      
      if (mission != null) {
        debugPrint('Completing mission: ${mission.name}');
        mission.isCompleted = true;
        await box.put(missionId, mission);
        
        // Update user stats
        final user = await getUser();
        user.addXp(mission.xp);
        
        // Check if this is a quick mission (starting with 'quick_')
        if (missionId.startsWith('quick_')) {
          // For quick missions, add fixed amount of stat points (reduced from 5 to 2)
          user.addStatPoints(mission.type.toString().split('.').last, mission.xp, extraPoints: 2);
          debugPrint('Added extra stat points for quick mission');
        } else {
          // Regular missions use the normal calculation
          user.addStatPoints(mission.type.toString().split('.').last, mission.xp);
        }
        
        await saveUser(user);
        debugPrint('Mission completed and user updated');
      } else {
        debugPrint('Mission not found: $missionId');
      }
    } catch (e) {
      debugPrint('Error completing mission: $e');
      // Let the caller handle the error
      rethrow;
    }
  }
  
  // Reset app data (for troubleshooting)
  static Future<void> resetAllData() async {
    try {
      debugPrint('Resetting all app data...');
      
      // Close all boxes
      await Hive.close();
      
      // Delete boxes
      await Hive.deleteBoxFromDisk(userBoxName);
      await Hive.deleteBoxFromDisk(missionsBoxName);
      
      // Reset flags
      _initialized = false;
      _initAttempts = 0;
      
      // Reinitialize
      await init();
      
      debugPrint('App data reset successfully');
    } catch (e) {
      debugPrint('Error resetting app data: $e');
      
      // Force more aggressive reset
      await _forceReset();
      
      // Try initializing again
      await init();
    }
  }

  // Get daily missions only
  static Future<List<Mission>> getDailyMissions() async {
    try {
      if (!_initialized) {
        await init();
      }
      
      final box = _getMissionsBox();
      
      // Safety check for corrupted data
      if (box.isEmpty) {
        debugPrint('Missions box is empty');
        return [];
      }
      
      // Get all missions as a list first
      final allMissions = box.values.toList();
      
      // Filter only daily missions
      final List<Mission> dailyMissions = allMissions
          .where((mission) => mission.isDaily)
          .toList();
      
      // Sort by date
      dailyMissions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return dailyMissions;
    } catch (e) {
      debugPrint('Error getting daily missions: $e');
      return [];
    }
  }
} 