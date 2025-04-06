import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';

class SkillSelector extends StatefulWidget {
  final List<String> selectedSkills;
  final Function(List<String>) onSkillsChanged;
  final String? title;
  final List<String>? initialSkills;

  const SkillSelector({
    Key? key,
    required this.selectedSkills,
    required this.onSkillsChanged,
    this.title,
    this.initialSkills,
  }) : super(key: key);

  @override
  State<SkillSelector> createState() => _SkillSelectorState();
}

class _SkillSelectorState extends State<SkillSelector> {
  final List<String> _majorSkills = [
    // Major Skills
    'Dart',
    'Python',
    'Java',
    'C++',
    'JavaScript',
    'Swift',
    'Kotlin',
    'TypeScript',
    'PHP',
    'Ruby',
    'Go',
    'C#',
    'SQL',
    'R',
    'HTML',
    'CSS',
    'Marketing',
    'SEO',
    'Data Analysis',
    'Machine Learning',
    'Cybersecurity',
    'UI/UX Design',
    'DevOps',
    'Blockchain',
    'Cloud Computing',
    'Game Development',
    'Mobile App Development',
    'Web Development',
    'Backend Development',
    'Frontend Development',
    'AI',
    'Networking',
    'Embedded Systems',
    'Automation',
    'System Administration',
    'Programming',
    'Design',
    'Writing',
    'Research',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Communication',
    'Leadership',
    'Project Management'
  ];

  final List<String> _minorSkills = [
    // Minor Skills (Frameworks & Tools)
    'Flutter',
    'React',
    'Vue.js',
    'Angular',
    'Django',
    'Flask',
    'FastAPI',
    'Spring Boot',
    'Express.js',
    'NestJS',
    'Next.js',
    'Nuxt.js',
    'Laravel',
    'Ruby on Rails',
    'ASP.NET',
    'TensorFlow',
    'PyTorch',
    'Scikit-learn',
    'OpenCV',
    'Numpy',
    'Pandas',
    'Matplotlib',
    'Tailwind CSS',
    'Bootstrap',
    'SASS',
    'LESS',
    'Redux',
    'MobX',
    'GetX',
    'Riverpod',
    'Provider',
    'Firebase',
    'Supabase',
    'PostgreSQL',
    'MySQL',
    'MongoDB',
    'Redis',
    'GraphQL',
    'REST API',
    'gRPC',
    'Docker',
    'Kubernetes',
    'Jenkins',
    'AWS',
    'Azure',
    'Google Cloud',
    'DigitalOcean',
    'Unity',
    'Unreal Engine',
    'Godot',
    'TensorFlow.js',
    'Selenium',
    'Puppeteer',
    'Jest',
    'Mocha',
    'Cypress',
    'JUnit',
    'Pytest',
    'Git',
    'GitHub',
    'GitLab',
    'Bitbucket',
    'Jira',
    'Trello',
    'Figma',
    'Adobe XD'
  ];

  @override
  Widget build(BuildContext context) {
    // Filter out already selected skills
    final availableSkillsFiltered = [..._majorSkills, ..._minorSkills]
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
                    final updatedSkills = List<String>.from(widget
                        .selectedSkills)
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
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
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
    final majorSkillsFiltered = availableSkills
        .where((skill) => _majorSkills.contains(skill))
        .toList();

    final minorSkillsFiltered = availableSkills
        .where((skill) => _minorSkills.contains(skill))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.title ?? 'Select a Skill'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // Set a fixed height for scrolling
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search skills...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      // This will rebuild the dialog with filtered skills
                      if (value.isEmpty) {
                        availableSkills = [..._majorSkills, ..._minorSkills]
                            .where((skill) =>
                        !widget.selectedSkills.contains(skill))
                            .toList();
                      } else {
                        availableSkills = [..._majorSkills, ..._minorSkills]
                            .where((skill) =>
                        !widget.selectedSkills.contains(skill) &&
                            skill.toLowerCase().contains(value.toLowerCase()))
                            .toList();
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Major Skills section
                const Text(
                  'Major Skills',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Divider(),

                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Major skills list
                      ...majorSkillsFiltered.map((skill) =>
                          ListTile(
                            title: Text(skill),
                            onTap: () {
                              final updatedSkills = List<String>.from(
                                  widget.selectedSkills)
                                ..add(skill);
                              widget.onSkillsChanged(updatedSkills);
                              Navigator.pop(context);
                            },
                          )).toList(),

                      // Minor skills section
                      if (minorSkillsFiltered.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Minor Skills (Frameworks & Tools)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Divider(),
                        ...minorSkillsFiltered.map((skill) =>
                            ListTile(
                              title: Text(skill),
                              onTap: () {
                                final updatedSkills = List<String>.from(
                                    widget.selectedSkills)
                                  ..add(skill);
                                widget.onSkillsChanged(updatedSkills);
                                Navigator.pop(context);
                              },
                            )).toList(),
                      ],
                    ],
                  ),
                ),
              ],
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
