import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';

class StatItem extends StatelessWidget {
  final String statName;
  final int points;
  final IconData icon;
  final Color color;

  const StatItem({
    Key? key,
    required this.statName,
    required this.points,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate percentage for progress bar (capped at 100%)
    double percentage = points / 100.0;
    if (percentage > 1.0) percentage = 1.0;

    return Card(
      elevation: 2,
      color: Colors.grey.shade800,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  statName.substring(0, 1).toUpperCase() + statName.substring(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$points',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                const Text(
                  ' points',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearPercentIndicator(
              animation: true,
              animationDuration: 1000,
              lineHeight: 10.0,
              percent: percentage,
              progressColor: color,
              backgroundColor: color.withOpacity(0.2),
              barRadius: const Radius.circular(10),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to get the appropriate icon for a stat
IconData getStatIcon(String statName) {
  switch (statName.toLowerCase()) {
    case 'strength':
      return Icons.fitness_center;
    case 'intelligence':
      return Icons.psychology;
    case 'discipline':
      return Icons.schedule;
    case 'willpower':
      return Icons.bolt;
    case 'agility':
      return Icons.directions_run;
    case 'endurance':
      return Icons.battery_full;
    default:
      return Icons.star;
  }
}

// Helper function to get the appropriate color for a stat
Color getStatColor(String statName) {
  switch (statName.toLowerCase()) {
    case 'strength':
      return Colors.red;
    case 'intelligence':
      return Colors.blue;
    case 'discipline':
      return Colors.purple;
    case 'willpower':
      return Colors.amber;
    case 'agility':
      return Colors.green;
    case 'endurance':
      return Colors.orange;
    default:
      return Colors.grey;
  }
} 