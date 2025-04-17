import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/models/user.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';
import 'package:solo_leveling_app/screens/dashboard_screen.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'package:solo_leveling_app/services/background_image_service.dart';
import 'dart:ui' show PlatformDispatcher;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Keep track of whether we've registered adapters
bool _adaptersRegistered = false;

// We'll use regular boxes instead of lazy boxes to avoid conflicts
bool _useRegularBoxes = true;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Basic error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    // In release mode, log to console instead of showing error UI
    if (kReleaseMode) {
      debugPrint('Flutter error caught: ${details.exception}');
    } else {
      FlutterError.presentError(details);
    }
  };
  
  try {
    // Initialize Hive with default location
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(MissionAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(MissionTypeAdapter());
    
    // Open boxes
    await Hive.openBox<Mission>('missionsBox');
    await Hive.openBox<User>('userBox');
    await Hive.openBox('settingsBox'); // Box for app settings
    
    // Create initial user if needed
    final userBox = Hive.box<User>('userBox');
    if (userBox.isEmpty) {
      await userBox.put('currentUser', User.initial());
    }
    
    // Initialize the background worker
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: !kReleaseMode
    );
    
    // Initialize the background service
    await BackgroundImageService.initialize();
    
    // Run app
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error during initialization: $e');
    
    // In release mode, try to recover gracefully
    if (kReleaseMode) {
      // Try to run with minimal functionality
      runApp(const MyApp());
    } else {
      // In debug mode, show error screen
      runApp(const ErrorApp());
    }
  }
}

// The callback dispatcher for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('Background task started: $task');
    try {
      if (task == BackgroundImageService.uniqueWorkName) {
        // Run the image generation task
        return await _generateImages();
      }
      return true;
    } catch (e) {
      debugPrint('Error in background task: $e');
      return false;
    }
  });
}

// Re-implement the image generation logic here to avoid dependency issues
Future<bool> _generateImages() async {
  // Implementation goes here - simplified version just for registration
  debugPrint('Image generation task executed');
  return true;
}

Future<void> registerAdapters() async {
  debugPrint('Checking adapter registration...');
  
  // Skip if already registered in this session
  if (_adaptersRegistered) {
    debugPrint('Adapters already registered in this session, skipping');
    return;
  }
  
  debugPrint('Registering adapters...');
  try {
    // Try-catch each adapter registration separately
    try {
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(MissionTypeAdapter());
        debugPrint('Registered MissionTypeAdapter');
      }
    } catch (e) {
      debugPrint('Error registering MissionTypeAdapter: $e');
    }
    
    try {
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MissionAdapter());
        debugPrint('Registered MissionAdapter');
      }
    } catch (e) {
      debugPrint('Error registering MissionAdapter: $e');
    }
    
    try {
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UserAdapter());
        debugPrint('Registered UserAdapter');
      }
    } catch (e) {
      debugPrint('Error registering UserAdapter: $e');
    }
    
    _adaptersRegistered = true;
    debugPrint('Adapters registered successfully');
  } catch (e) {
    debugPrint('General error during adapter registration: $e');
    rethrow;
  }
}

Future<void> openBoxes() async {
  debugPrint('Opening Hive boxes...');
  try {
    // Close any open boxes first to avoid conflicts
    await Hive.close();
    
    // Open boxes consistently using the same type
    if (_useRegularBoxes) {
      debugPrint('Using regular boxes');
      await Hive.openBox<Mission>('missionsBox');
      await Hive.openBox<User>('userBox');
    } else {
      debugPrint('Using lazy boxes');
      await Hive.openLazyBox<Mission>('missionsBox');
      await Hive.openLazyBox<User>('userBox');
    }
    
    // Initialize user if needed
    if (_useRegularBoxes) {
      final userBox = Hive.box<User>('userBox');
      if (!userBox.containsKey('currentUser')) {
        debugPrint('Creating initial user');
        await userBox.put('currentUser', User.initial());
      }
    } else {
      final userBox = Hive.lazyBox<User>('userBox');
      if (!(await userBox.containsKey('currentUser'))) {
        debugPrint('Creating initial user');
        await userBox.put('currentUser', User.initial());
      }
    }
    
    debugPrint('Boxes opened successfully');
  } catch (e) {
    debugPrint('Error opening boxes: $e');
    
    // Try recovery
    try {
      // Delete box files
      await Hive.deleteBoxFromDisk('missionsBox');
      await Hive.deleteBoxFromDisk('userBox');
      
      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try again with regular boxes
      _useRegularBoxes = true;
      await Hive.openBox<Mission>('missionsBox');
      await Hive.openBox<User>('userBox');
      
      // Initialize user
      final userBox = Hive.box<User>('userBox');
      if (!userBox.containsKey('currentUser')) {
        await userBox.put('currentUser', User.initial());
      }
      
      debugPrint('Box recovery successful');
    } catch (e) {
      debugPrint('Fatal error during box recovery: $e');
      rethrow;
    }
  }
}

// For displaying error state if app fails to initialize
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 80),
              const SizedBox(height: 16),
              const Text(
                'App Initialization Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please uninstall and reinstall the app',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  try {
                    Hive.deleteFromDisk();
                  } catch (e) {
                    debugPrint('Error clearing data: $e');
                  }
                },
                child: const Text('Clear Data & Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider()..init(),
      child: MaterialApp(
        title: 'Daily Quests',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF6200EA),
            secondary: const Color(0xFF03DAC6),
            surface: Colors.grey.shade900,
            background: Colors.black,
            error: Colors.red.shade400,
          ),
          scaffoldBackgroundColor: Colors.black,
          canvasColor: Colors.black,
          cardColor: Colors.grey.shade900,
          dialogBackgroundColor: Colors.grey.shade900,
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Color(0xFF6200EA),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF6200EA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            color: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6200EA),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF6200EA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            color: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const DashboardScreen(),
        // Add error handling for navigation errors
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48)
                  ],
                ),
              ),
            );
          };
          return child ?? const SizedBox();
        },
      ),
    );
  }
}

// Temporary adapters for development until code generation is set up
class MissionTypeAdapter extends TypeAdapter<MissionType> {
  @override
  final int typeId = 2;

  @override
  MissionType read(BinaryReader reader) {
    return MissionType.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, MissionType obj) {
    writer.writeInt(obj.index);
  }
}

class MissionAdapter extends TypeAdapter<Mission> {
  @override
  final int typeId = 0;

  @override
  Mission read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final description = reader.readString();
    final xp = reader.readInt();
    final type = MissionType.values[reader.readInt()];
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final isCompleted = reader.readBool();
    
    return Mission(
      id: id,
      name: name,
      description: description,
      xp: xp,
      type: type,
      createdAt: createdAt,
      isCompleted: isCompleted,
    );
  }

  @override
  void write(BinaryWriter writer, Mission obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.description);
    writer.writeInt(obj.xp);
    writer.writeInt(obj.type.index);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeBool(obj.isCompleted);
  }
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 1;

  @override
  User read(BinaryReader reader) {
    final id = reader.readString();
    final level = reader.readInt();
    final currentXp = reader.readInt();
    final nextLevelXp = reader.readInt();
    
    // Read stats map
    final statsLength = reader.readInt();
    final stats = <String, int>{};
    for (var i = 0; i < statsLength; i++) {
      final key = reader.readString();
      final value = reader.readInt();
      stats[key] = value;
    }
    
    final rank = reader.readString();
    
    return User(
      id: id,
      level: level,
      currentXp: currentXp,
      nextLevelXp: nextLevelXp,
      stats: stats,
      rank: rank,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.level);
    writer.writeInt(obj.currentXp);
    writer.writeInt(obj.nextLevelXp);
    
    // Write stats map
    writer.writeInt(obj.stats.length);
    obj.stats.forEach((key, value) {
      writer.writeString(key);
      writer.writeInt(value);
    });
    
    writer.writeString(obj.rank);
  }
}
