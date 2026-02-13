import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';

class SkillSelector extends StatefulWidget {
  final List<String> selectedSkills;
  final Function(List<String>) onSkillsChanged;
  final String? title;
  final List<String>? initialSkills;

  const SkillSelector({
    super.key,
    required this.selectedSkills,
    required this.onSkillsChanged,
    this.title,
    this.initialSkills,
  });

  @override
  State<SkillSelector> createState() => _SkillSelectorState();
}

class _SkillSelectorState extends State<SkillSelector> {
  static const List<String> _majorSkills = [
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

  static const List<String> _minorSkills = [
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

  String _searchQuery = ''; // ✅ NEW: search query state

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final availableSkillsFiltered = [..._majorSkills, ..._minorSkills]
        .where((skill) => !widget.selectedSkills.contains(skill))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : AppTheme.lightGrayColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.selectedSkills.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedSkills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  deleteIconColor: AppTheme.primaryColor,
                  onDeleted: () {
                    final updatedSkills =
                        List<String>.from(widget.selectedSkills)..remove(skill);
                    widget.onSkillsChanged(updatedSkills);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (availableSkillsFiltered.isNotEmpty)
            InkWell(
              onTap: () {
                _showSkillSelectionDialog(availableSkillsFiltered, isDarkMode);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isDarkMode
                          ? Colors.grey[600]!
                          : Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select a skill',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.grey[300]
                            : Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(
                      Icons.add_circle_outline,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          if (availableSkillsFiltered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'All available skills have been selected',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSkillSelectionDialog(
      List<String> availableSkills, bool isDarkMode) {
    _searchQuery = '';
    bool showingMajorSkills = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final majorSkillsFiltered = availableSkills
                .where((skill) =>
                    _majorSkills.contains(skill) &&
                    skill.toLowerCase().contains(_searchQuery))
                .toList();

            final minorSkillsFiltered = availableSkills
                .where((skill) =>
                    _minorSkills.contains(skill) &&
                    skill.toLowerCase().contains(_searchQuery))
                .toList();

            return AlertDialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : null,
              title: Text(
                widget.title ?? 'Select a Skill',
                style:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Search skills...',
                        hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                        prefixIcon: Icon(Icons.search,
                            color: isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[700]),
                        filled: true,
                        fillColor:
                            isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: showingMajorSkills
                                  ? AppTheme.primaryColor
                                  : (isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey.shade300),
                              foregroundColor: showingMajorSkills
                                  ? Colors.white
                                  : (isDarkMode ? Colors.white : Colors.black),
                            ),
                            onPressed: () =>
                                setState(() => showingMajorSkills = true),
                            child: const Text('Major Skills'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !showingMajorSkills
                                  ? AppTheme.primaryColor
                                  : (isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey.shade300),
                              foregroundColor: !showingMajorSkills
                                  ? Colors.white
                                  : (isDarkMode ? Colors.white : Colors.black),
                            ),
                            onPressed: () =>
                                setState(() => showingMajorSkills = false),
                            child: const Text('Minor Skills'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      showingMajorSkills
                          ? 'Major Skills'
                          : 'Minor Skills (Frameworks & Tools)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: showingMajorSkills
                            ? majorSkillsFiltered.length
                            : minorSkillsFiltered.length,
                        itemBuilder: (context, index) {
                          final skill = showingMajorSkills
                              ? majorSkillsFiltered[index]
                              : minorSkillsFiltered[index];
                          return ListTile(
                            title: Text(
                              skill,
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                            ),
                            onTap: () {
                              final updatedSkills =
                                  List<String>.from(widget.selectedSkills)
                                    ..add(skill);
                              widget.onSkillsChanged(updatedSkills);
                              Navigator.pop(dialogContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
