import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/project_model.dart';

import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/providers/matchmaking_provider.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';

import '../../models/match_making_model.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  bool _isLoading = false;
  ProjectModel? _selectedProject;
  List<ProjectModel> _userProjects = [];

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserProjects();
    });
  }

  Future<void> _fetchUserProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projectProvider =
          Provider.of<ProjectProvider>(context, listen: false);
      await projectProvider.fetchProjects();

      setState(() {
        _userProjects = projectProvider.projects;
        _isLoading = false;

        // If there are projects, find matches for the first one by default
        if (_userProjects.isNotEmpty) {
          _selectedProject = _userProjects.first;
          _findMatches();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching projects: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _findMatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // If a project is selected, use its required skills for matching
      if (_selectedProject != null &&
          _selectedProject!.requiredSkills.isNotEmpty) {
        await Provider.of<MatchmakingProvider>(context, listen: false)
            .findMatches(requiredSkills: _selectedProject!.requiredSkills);
      } else {
        // Otherwise, use the user's skills
        await Provider.of<MatchmakingProvider>(context, listen: false)
            .findMatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding matches: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat(MatchmakingResultModel match) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final chatId = await chatProvider.createChat(
      recipientId: match.userId,
      recipientName: match.name,
    );

    if (chatId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            chatName: match.name,
          ),
        ),
      );
    }
  }

  void _selectProject(ProjectModel? project) {
    setState(() {
      _selectedProject = project;
    });
    _findMatches();
  }

  @override
  Widget build(BuildContext context) {
    final matchmakingProvider = Provider.of<MatchmakingProvider>(context);
    final matches = matchmakingProvider.matchResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Team Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _findMatches,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(Icons.filter_list,
                              color: AppTheme.primaryColor),
                          title: const Text('Filter Options'),
                          onTap: () {
                            Navigator.pop(context);
                            // Show filter options
                          },
                        ),
                        ListTile(
                          leading:
                              Icon(Icons.sort, color: AppTheme.primaryColor),
                          title: const Text('Sort By'),
                          onTap: () {
                            Navigator.pop(context);
                            // Show sort options
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.help_outline,
                              color: AppTheme.primaryColor),
                          title: const Text('How Matchmaking Works'),
                          onTap: () {
                            Navigator.pop(context);
                            // Show help info
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Project selector
          if (_userProjects.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find matches for:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedProject?.id,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('My Skills'),
                      ),
                      ..._userProjects.map((project) {
                        return DropdownMenuItem<String>(
                          value: project.id,
                          child: Text(project.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        _selectProject(null);
                      } else {
                        final project = _userProjects.firstWhere(
                          (p) => p.id == value,
                          orElse: () => _userProjects.first,
                        );
                        _selectProject(project);
                      }
                    },
                  ),
                  if (_selectedProject != null &&
                      _selectedProject!.requiredSkills.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedProject!.requiredSkills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
          ],

          // Matches list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : matches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'No matches found',
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _findMatches,
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _findMatches,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final match = matches[index];
                            return _buildMatchCard(match);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(MatchmakingResultModel match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: match.avatarUrl != null
                  ? NetworkImage(match.avatarUrl!)
                  : null,
              child: match.avatarUrl == null
                  ? Text(
                      match.name.isNotEmpty ? match.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        match.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(match.compatibilityScore * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last active: ${match.responseTime}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Skills',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: match.skills.map((skill) {
                      // Highlight matching skills if a project is selected
                      final isMatchingSkill = _selectedProject != null &&
                          _selectedProject!.requiredSkills.contains(skill);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isMatchingSkill
                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                              : AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: isMatchingSkill
                              ? Border.all(color: AppTheme.primaryColor)
                              : null,
                        ),
                        child: Text(
                          skill,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: isMatchingSkill
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _startChat(match),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(100, 36),
                    ),
                    child: const Text('Chat'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
