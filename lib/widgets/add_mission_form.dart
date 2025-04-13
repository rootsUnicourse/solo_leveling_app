import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';

class AddMissionForm extends StatefulWidget {
  const AddMissionForm({Key? key}) : super(key: key);

  @override
  State<AddMissionForm> createState() => _AddMissionFormState();
}

class _AddMissionFormState extends State<AddMissionForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _xpController = TextEditingController();
  MissionType _selectedType = MissionType.strength;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      
      provider.addMission(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        xp: int.parse(_xpController.text.trim()),
        type: _selectedType,
      );

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Mission',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Mission Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.task),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a mission name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mission Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _xpController,
              decoration: const InputDecoration(
                labelText: 'XP (1-1000)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.star),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter XP amount';
                }
                final xp = int.tryParse(value);
                if (xp == null || xp <= 0 || xp > 1000) {
                  return 'XP must be between 1 and 1000';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MissionType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Mission Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: MissionType.values.map((type) {
                final provider = Provider.of<AppProvider>(context);
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        provider.getMissionTypeIcon(type),
                        color: provider.getMissionTypeColor(type),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(type.toString().split('.').last),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
                child: const Text(
                  'Add Mission',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 