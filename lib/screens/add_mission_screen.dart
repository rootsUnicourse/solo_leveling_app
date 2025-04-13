import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solo_leveling_app/models/mission.dart';
import 'package:solo_leveling_app/providers/app_provider.dart';

class AddMissionScreen extends StatefulWidget {
  const AddMissionScreen({Key? key}) : super(key: key);

  @override
  State<AddMissionScreen> createState() => _AddMissionScreenState();
}

class _AddMissionScreenState extends State<AddMissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _xpController = TextEditingController();
  MissionType _selectedType = MissionType.strength;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Mission'),
        backgroundColor: Colors.grey.shade900,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mission name input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Mission Name',
                  hintText: 'Enter a name for your mission',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.assignment),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a mission name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // Mission description input
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what needs to be done',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // XP reward input
              TextFormField(
                controller: _xpController,
                decoration: InputDecoration(
                  labelText: 'XP Reward',
                  hintText: 'How many XP is this mission worth?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.stars),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter XP amount';
                  }
                  try {
                    final xp = int.parse(value);
                    if (xp <= 0) {
                      return 'XP must be greater than 0';
                    }
                    if (xp > 100) {
                      return 'Maximum XP is 100';
                    }
                  } catch (_) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24.0),

              // Mission type selection
              _buildMissionTypeSelector(provider),
              const SizedBox(height: 32.0),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting 
                  ? null 
                  : () => _submitMission(context, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.getMissionTypeColor(_selectedType),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'CREATE MISSION',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionTypeSelector(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mission Type:',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: MissionType.values.map((type) {
            final isSelected = _selectedType == type;
            final typeColor = provider.getMissionTypeColor(type);
            final typeIcon = provider.getMissionTypeIcon(type);
            final typeName = type.toString().split('.').last;
            
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedType = type;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? typeColor.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isSelected ? typeColor : Colors.grey,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      typeIcon,
                      color: isSelected ? typeColor : Colors.grey,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      typeName[0].toUpperCase() + typeName.substring(1),
                      style: TextStyle(
                        color: isSelected ? typeColor : Colors.grey,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submitMission(BuildContext context, AppProvider provider) async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show loading state
    setState(() {
      _isSubmitting = true;
    });

    try {
      final xp = int.parse(_xpController.text);
      
      // Add mission via provider
      await provider.addMission(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        xp: xp,
        type: _selectedType,
      );

      // Success - go back to previous screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mission created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Show error if something went wrong
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding mission: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        );
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
} 