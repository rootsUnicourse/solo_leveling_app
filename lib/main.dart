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
import 'dart:ui' show PlatformDispatcher;

void main() async {
  runZonedGuarded(() async {
    try {
      // Important: Ensure bindings are initialized first
      WidgetsFlutterBinding.ensureInitialized();
      
      // Configure error handlers
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error caught: ${details.exception}');
      };
      
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Platform error caught: $error');
        return true;
      };

      debugPrint('Starting Hive initialization...');
      
      try {
        // Initialize Hive - only do this once
        await Hive.initFlutter();
        debugPrint('Hive.initFlutter completed');
        
        // Register the required adapters
        registerAdapters();
        
        // Open the boxes - in the correct order
        await openBoxes();
        
        // Initialize storage service after all setup
        await StorageService.init();
        
        debugPrint('App initialization successful. Running app...');
        runApp(const MyApp());
      } catch (e, stack) {
        debugPrint('Error during Hive initialization: $e');
        debugPrint('Stack trace: $stack');
        
        if (!Hive.isBoxOpen('missionsBox') || !Hive.isBoxOpen('userBox')) {
          debugPrint('Attempting recovery path...');
          try {
            await Hive.deleteFromDisk();
            await Hive.initFlutter();
            
            registerAdapters();
            await openBoxes();
            await StorageService.init();
            
            runApp(const MyApp());
          } catch (e) {
            debugPrint('Fatal error during recovery: $e');
            runApp(const ErrorApp());
          }
        } else {
          runApp(const MyApp());
        }
      }
    } catch (e, stack) {
      debugPrint('Uncaught error during setup: $e');
      debugPrint('Stack trace: $stack');
      runApp(const ErrorApp());
    }
  }, (error, stackTrace) {
    // Capture zone errors
    debugPrint('ZonedGuarded caught error: $error');
    debugPrint(stackTrace.toString());
  });
}

void registerAdapters() {
  debugPrint('Registering adapters...');
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(MissionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MissionAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(UserAdapter());
  }
  debugPrint('Adapters registered successfully');
}

Future<void> openBoxes() async {
  debugPrint('Opening Hive boxes...');
  try {
    if (!Hive.isBoxOpen('missionsBox')) {
      await Hive.openBox<Mission>('missionsBox');
    }
    if (!Hive.isBoxOpen('userBox')) {
      await Hive.openBox<User>('userBox');
    }
    debugPrint('Boxes opened successfully');
  } catch (e) {
    debugPrint('Error opening boxes, trying to recreate them: $e');
    // If boxes are corrupted, try to delete and recreate them
    await Hive.deleteBoxFromDisk('missionsBox');
    await Hive.deleteBoxFromDisk('userBox');
    
    await Hive.openBox<Mission>('missionsBox');
    await Hive.openBox<User>('userBox');
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
