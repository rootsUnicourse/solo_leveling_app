import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';
import 'package:solo_leveling_app/widgets/add_mission_form.dart';
import 'package:solo_leveling_app/widgets/mission_item.dart';
import 'package:solo_leveling_app/widgets/stat_item.dart';
import 'package:flutter/foundation.dart';
import 'package:solo_leveling_app/services/storage_service.dart';
import 'package:solo_leveling_app/widgets/quick_mission_popup.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Delay to ensure the context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowQuickMission();
    });
  }

  void _maybeShowQuickMission() {
    // Show quick mission randomly (30% chance)
    if (Random().nextDouble() < 0.3) {
      QuickMissionPopup.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: null,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 48,
        actions: [
          // Reset button (for troubleshooting)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset App Data'),
                    content: const Text('This will reset all your data. Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await StorageService.resetAllData();
                  // Refresh the provider
                  if (mounted) {
                    Provider.of<AppProvider>(context, listen: false).init();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('App data reset successfully')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.user == null) {
            return const Center(child: Text('Error loading user data'));
          }

          final user = provider.user!;

          return RefreshIndicator(
            onRefresh: () async {
              await provider.init();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info section
                  _buildUserInfoSection(context, user),

                  // Stats grid
                  _buildStatsGrid(context, user),

                  // Active missions section
                  _buildActiveMissionsSection(context, provider),
                  
                  // Completed missions (history) section
                  if (provider.completedMissions.isNotEmpty)
                    _buildCompletedMissionsSection(context, provider),

                  // Bottom padding
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserInfoSection(BuildContext context, user) {
    // Calculate percentage for XP progress bar
    final double xpPercentage = user.currentXp / user.nextLevelXp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Character image
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Builder(
                    builder: (context) {
                      try {
                        return Image.asset(
                          user.getCharacterImagePath(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error loading image: $error');
                            return Container(
                              color: Colors.grey.withOpacity(0.3),
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            );
                          },
                        );
                      } catch (e) {
                        debugPrint('Exception when loading image: $e');
                        return Container(
                          color: Colors.grey.withOpacity(0.3),
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Level and XP info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${user.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.rank,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'XP: ${user.currentXp}/${user.nextLevelXp}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                LinearPercentIndicator(
                  animation: true,
                  lineHeight: 10.0,
                  animationDuration: 1000,
                  percent: xpPercentage,
                  progressColor: Colors.amber,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  barRadius: const Radius.circular(10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
            ),
            itemCount: user.stats.length,
            itemBuilder: (context, index) {
              final statName = user.stats.keys.elementAt(index);
              final points = user.stats[statName] ?? 0;
              
              return StatItem(
                statName: statName,
                points: points,
                icon: getStatIcon(statName),
                color: getStatColor(statName),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMissionsSection(BuildContext context, AppProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Missions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: const AddMissionForm(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Colors.grey.shade700),
          if (provider.activeMissions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No active missions',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add a mission to start leveling up!',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.activeMissions.length,
              itemBuilder: (context, index) {
                return MissionItem(
                  mission: provider.activeMissions[index],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedMissionsSection(BuildContext context, AppProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mission History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Divider(height: 24, color: Colors.grey.shade600),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.completedMissions.length,
            itemBuilder: (context, index) {
              return MissionItem(
                mission: provider.completedMissions[index],
              );
            },
          ),
        ],
      ),
    );
  }
} 