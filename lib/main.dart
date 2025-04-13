import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/models/user.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';
import 'package:solo_leveling_app/screens/dashboard_screen.dart';
import 'package:solo_leveling_app/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register adapters manually since code generation is not yet set up
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(MissionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MissionAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(UserAdapter());
  }
  
  // Open boxes
  await Hive.openBox<Mission>('missionsBox');
  await Hive.openBox<User>('userBox');
  
  // Initialize StorageService after adapters are registered
  await StorageService.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider()..init(),
      child: MaterialApp(
        title: 'Solo Leveling App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6200EA),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const DashboardScreen(),
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
