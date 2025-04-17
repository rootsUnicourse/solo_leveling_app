import 'package:hive/hive.dart';
import 'package:solo_leveling_app/services/ai_image_service.dart';

part 'user.g.dart';

@HiveType(typeId: 1)
class User {
  @HiveField(0)
  final String id;

  @HiveField(1)
  int level;

  @HiveField(2)
  int currentXp;

  @HiveField(3)
  int nextLevelXp;

  @HiveField(4)
  Map<String, int> stats;

  @HiveField(5)
  String rank;
  
  @HiveField(6)
  bool hasCustomHunterImage;

  User({
    required this.id,
    this.level = 1,
    this.currentXp = 0,
    this.nextLevelXp = 1000,
    required this.stats,
    this.rank = 'E-Rank Hunter',
    this.hasCustomHunterImage = false,
  });

  factory User.initial() {
    return User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      stats: {
        'strength': 0,
        'intelligence': 0,
        'discipline': 0,
        'willpower': 0,
        'agility': 0,
        'endurance': 0,
      },
    );
  }

  // Calculate XP needed for next level
  int calculateNextLevelXp(int level) {
    return 1000 + (level - 1) * 500;
  }

  // Add XP and level up if necessary
  void addXp(int xp) {
    currentXp += xp;
    
    while (currentXp >= nextLevelXp) {
      // Level up
      level++;
      currentXp -= nextLevelXp;
      nextLevelXp = calculateNextLevelXp(level);
      
      // Update rank based on level
      updateRank();
    }
  }

  // Add stat points based on mission type and XP
  void addStatPoints(String statType, int xp, {int extraPoints = 0}) {
    // 1 stat point per 100 XP, plus any extra points
    int statPoints = (xp ~/ 100) + extraPoints;
    stats[statType] = (stats[statType] ?? 0) + statPoints;
  }

  // Update rank based on level
  void updateRank() {
    if (level >= 20) {
      rank = 'S-Rank Hunter';
    } else if (level >= 15) {
      rank = 'A-Rank Hunter';
    } else if (level >= 10) {
      rank = 'B-Rank Hunter';
    } else if (level >= 5) {
      rank = 'C-Rank Hunter';
    } else if (level >= 3) {
      rank = 'D-Rank Hunter';
    } else {
      rank = 'E-Rank Hunter';
    }
  }

  // Get the appropriate character image based on level
  Future<String> getCharacterImagePath() async {
    try {
      // Check if user has custom hunter images
      if (hasCustomHunterImage) {
        // Determine which image level to use based on current level
        int imageLevel;
        if (level >= 25) {
          imageLevel = 25; // S-Rank (25+)
        } else if (level >= 20) {
          imageLevel = 20; // S-Rank (20-24)
        } else if (level >= 15) {
          imageLevel = 15; // A-Rank (15-19)
        } else if (level >= 10) {
          imageLevel = 10; // B-Rank (10-14)
        } else if (level >= 5) {
          imageLevel = 5;  // C-Rank (5-9)
        } else if (level >= 3) {
          imageLevel = 3;  // D-Rank (3-4)
        } else {
          imageLevel = 1;  // E-Rank (1-2)
        }
        
        // Try to get the custom image for this level
        final customImagePath = await AIImageService.getUserImagePathForLevel(imageLevel);
        if (customImagePath != null) {
          return customImagePath;
        }
      }
      
      // Fallback to default images if custom image not available
      if (level >= 25) {
        return 'assets/images/7.webp'; // Level 25+
      } else if (level >= 20) {
        return 'assets/images/6.webp'; // Level 20-24
      } else if (level >= 15) {
        return 'assets/images/5.webp'; // Level 15-19
      } else if (level >= 10) {
        return 'assets/images/4.webp'; // Level 10-14
      } else if (level >= 5) {
        return 'assets/images/2.jpg'; // Using 2.jpg for Level 5-9
      } else if (level >= 3) {
        return 'assets/images/2.jpg'; // Level 3-4
      } else {
        return 'assets/images/1.webp'; // Level 1-2
      }
    } catch (e) {
      // If any error occurs, return the default image
      return 'assets/images/1.webp';
    }
  }
} 