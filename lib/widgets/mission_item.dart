import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';

class MissionItem extends StatelessWidget {
  final Mission mission;

  const MissionItem({
    Key? key,
    required this.mission,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) {
              provider.completeMission(mission.id);
            },
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.check,
            label: 'Complete',
          ),
        ],
      ),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: mission.isCompleted 
              ? Colors.green.withOpacity(0.5) 
              : Colors.grey.withOpacity(0.2),
            width: mission.isCompleted ? 2 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: mission.isCompleted
              ? LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: provider.getMissionTypeColor(mission.type).withOpacity(0.2),
              radius: 24,
              child: Icon(
                provider.getMissionTypeIcon(mission.type),
                color: provider.getMissionTypeColor(mission.type),
                size: 24,
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                mission.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  decoration: mission.isCompleted ? TextDecoration.lineThrough : null,
                  color: mission.isCompleted ? Colors.grey : Colors.black,
                ),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.description,
                  style: TextStyle(
                    color: mission.isCompleted ? Colors.grey : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${mission.xp} XP',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: provider.getMissionTypeColor(mission.type).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mission.type.toString().split('.').last,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: provider.getMissionTypeColor(mission.type),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Checkbox(
              activeColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              value: mission.isCompleted,
              onChanged: (value) {
                if (value == true && !mission.isCompleted) {
                  provider.completeMission(mission.id);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
} 