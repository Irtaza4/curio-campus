import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';

class SkillSelector extends StatefulWidget {
  final List<String> selectedSkills;
  final Function(List<String>) onSkillsChanged;

  const SkillSelector({
    Key? key,
    required this.selectedSkills,
    required this.onSkillsChanged,
  }) : super(key: key);

  @override
  State<SkillSelector> createState() => _SkillSelectorState();
}

class _SkillSelectorState extends State<SkillSelector> {
  final List<String> _availableSkills = [
    'Programming',
    'Design',
    'Writing',
    'Research',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Marketing',
    'Communication',
    'Leadership',
    'Project Management',
    'Data Analysis',
    'Machine Learning',
    'UI/UX',
    'Mobile Development',
    'Web Development',
  ];

  @override
  Widget build(BuildContext context) {
    // Filter out already selected skills
    final availableSkillsFiltered = _availableSkills
        .where((skill) => !widget.selectedSkills.contains(skill))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.lightGrayColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected skills
          if (widget.selectedSkills.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedSkills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  deleteIconColor: AppTheme.primaryColor,
                  onDeleted: () {
                    final updatedSkills = List<String>.from(widget.selectedSkills)
                      ..remove(skill);
                    widget.onSkillsChanged(updatedSkills);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],

          // Add skill button
          if (availableSkillsFiltered.isNotEmpty)
            InkWell(
              onTap: () {
                _showSkillSelectionDialog(availableSkillsFiltered);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select a skill',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                    Icon(
                      Icons.add_circle_outline,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),

          if (availableSkillsFiltered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'All available skills have been selected',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSkillSelectionDialog(List<String> availableSkills) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select a Skill'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableSkills.length,
              itemBuilder: (context, index) {
                final skill = availableSkills[index];
                return ListTile(
                  title: Text(skill),
                  onTap: () {
                    final updatedSkills = List<String>.from(widget.selectedSkills)
                      ..add(skill);
                    widget.onSkillsChanged(updatedSkills);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

