import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/emergency_request_model.dart';
import 'package:curio_campus/providers/emergency_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:curio_campus/widgets/skill_selector.dart';
import 'package:intl/intl.dart';

class EditEmergencyRequestScreen extends StatefulWidget {
  final EmergencyRequestModel request;

  const EditEmergencyRequestScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<EditEmergencyRequestScreen> createState() => _EditEmergencyRequestScreenState();
}

class _EditEmergencyRequestScreenState extends State<EditEmergencyRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _deadline;
  late List<String> _requiredSkills;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.request.title);
    _descriptionController = TextEditingController(text: widget.request.description);
    _deadline = widget.request.deadline;
    _requiredSkills = List<String>.from(widget.request.requiredSkills);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deadline),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppTheme.primaryColor,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _deadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _updateEmergencyRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_requiredSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one required skill'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final emergencyProvider = Provider.of<EmergencyProvider>(context, listen: false);

      final success = await emergencyProvider.updateEmergencyRequest(
        requestId: widget.request.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requiredSkills: _requiredSkills,
        deadline: _deadline,
      );

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency request updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emergencyProvider.errorMessage ?? 'Failed to update emergency request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Emergency Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _titleController,
                hintText: 'Enter request title',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _descriptionController,
                hintText: 'Add detailed description',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Deadline
              const Text(
                'Deadline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDateTime(context),
                borderRadius: BorderRadius.circular(8),
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkMediumGrayColor : AppTheme.lightGrayColor, // Change container color based on theme
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM dd, yyyy - h:mm a').format(_deadline),
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black87, // Change text color based on theme
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),


              const SizedBox(height: 24),

              // Required skills
              const Text(
                'Peer Requirements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SkillSelector(
                selectedSkills: _requiredSkills,
                onSkillsChanged: (skills) {
                  setState(() {
                    _requiredSkills = skills;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Update button
              CustomButton(
                text: 'Update Emergency Request',
                isLoading: _isLoading,
                onPressed: _updateEmergencyRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

