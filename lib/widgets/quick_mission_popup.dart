import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';

class QuickMissionPopup extends StatelessWidget {
  const QuickMissionPopup({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QuickMissionPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final quickMission = _getRandomQuickMission();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: size.width,
        height: size.height,
        color: Colors.black.withOpacity(0.85),
        child: Stack(
          children: [
            // Top and bottom blue border lines
            Positioned(
              top: size.height * 0.2,
              left: 0,
              right: 0,
              child: _buildBorderLine(context),
            ),
            Positioned(
              bottom: size.height * 0.2,
              left: 0,
              right: 0,
              child: _buildBorderLine(context),
            ),
            
            // Main notification container
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with icon and label
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.notifications_active,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Text(
                              'NOTIFICATION',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Mission text
                      Text(
                        'QUICK MISSION AVAILABLE',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Mission details
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'QUICK MISSION',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              quickMission.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              quickMission.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            // Wrap the rewards in a Wrap widget to handle overflow
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: [
                                _buildRewardChip(
                                  context, 
                                  quickMission.type.toString().split('.').last,
                                  Provider.of<AppProvider>(context).getMissionTypeIcon(quickMission.type),
                                  Provider.of<AppProvider>(context).getMissionTypeColor(quickMission.type),
                                ),
                                _buildRewardChip(
                                  context, 
                                  '${quickMission.xp} XP',
                                  Icons.star,
                                  Colors.amber,
                                ),
                                _buildRewardChip(
                                  context, 
                                  '+2 Stats',
                                  Icons.trending_up,
                                  Colors.green,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildActionButton(
                            context,
                            'DECLINE',
                            Colors.grey.shade800,
                            Colors.white54,
                            () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 24),
                          _buildActionButton(
                            context,
                            'ACCEPT',
                            Theme.of(context).colorScheme.primary,
                            Colors.white,
                            () {
                              final provider = Provider.of<AppProvider>(context, listen: false);
                              
                              // Show a quick confirmation dialog with checkbox
                              showDialog(
                                context: context,
                                builder: (context) => _buildCompletionDialog(context, quickMission, provider),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBorderLine(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardChip(BuildContext context, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, 
    String label, 
    Color color, 
    Color textColor,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        elevation: 4,
        shadowColor: color.withOpacity(0.4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1.2,
          color: textColor,
        ),
      ),
    );
  }

  // Get a random quick mission
  Mission _getRandomQuickMission() {
    final quickMissions = [
      Mission(
        id: 'quick_1',
        name: 'Drink a Glass of Water',
        description: 'Hydrate yourself. Your body needs water to function properly.',
        xp: 50,
        type: MissionType.discipline,
        createdAt: DateTime.now(),
      ),
      Mission(
        id: 'quick_2',
        name: 'Do 20 Push-ups',
        description: 'Strengthen your upper body and core with this quick exercise.',
        xp: 100,
        type: MissionType.strength,
        createdAt: DateTime.now(),
      ),
      Mission(
        id: 'quick_3',
        name: '5-Minute Meditation',
        description: 'Take a moment to clear your mind and focus on your breathing.',
        xp: 75,
        type: MissionType.willpower,
        createdAt: DateTime.now(),
      ),
      Mission(
        id: 'quick_4',
        name: 'Take a Brief Walk',
        description: 'Get up and move around for 5 minutes to boost your circulation.',
        xp: 60,
        type: MissionType.endurance,
        createdAt: DateTime.now(),
      ),
      Mission(
        id: 'quick_5',
        name: 'Quick Brain Teaser',
        description: 'Solve a riddle or puzzle to exercise your mind.',
        xp: 90,
        type: MissionType.intelligence,
        createdAt: DateTime.now(),
      ),
      Mission(
        id: 'quick_6',
        name: '30-Second Plank',
        description: 'Hold a plank position for 30 seconds to strengthen your core.',
        xp: 80,
        type: MissionType.strength,
        createdAt: DateTime.now(),
      ),
      Mission(
        id: 'quick_7',
        name: 'Stretch Break',
        description: 'Take a minute to stretch your muscles and improve flexibility.',
        xp: 70,
        type: MissionType.agility,
        createdAt: DateTime.now(),
      ),
      Mission(
        id: 'quick_8',
        name: 'Clear Notifications',
        description: 'Check and clear notifications on your devices to stay organized.',
        xp: 55,
        type: MissionType.discipline,
        createdAt: DateTime.now(),
      ),
    ];

    return quickMissions[Random().nextInt(quickMissions.length)];
  }

  // Build the completion confirmation dialog
  Widget _buildCompletionDialog(BuildContext context, Mission mission, AppProvider provider) {
    bool isCompleted = false;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            'QUICK MISSION',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isCompleted,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (value) {
                      setState(() {
                        isCompleted = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'I have completed this mission',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Close both dialogs
              },
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isCompleted ? () async {
                // Close this dialog
                Navigator.of(context).pop();
                // Close the main quick mission popup
                Navigator.of(context).pop();
                
                // Complete the mission and show effect
                await provider.completeQuickMission(mission, context);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade700,
                disabledForegroundColor: Colors.grey.shade500,
              ),
              child: const Text('CONFIRM'),
            ),
          ],
        );
      },
    );
  }
} 