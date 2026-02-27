import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:portal_service_test/helpers/database_methods.dart';
import 'package:portal_service_test/models/user_model.dart';
import 'package:portal_service_test/theme/theme_provider.dart';
import 'package:portal_service_test/widgets/responsive_layout.dart';
import 'package:provider/provider.dart';

class FrontDeskScreen extends StatefulWidget {
  final String churchName;
  final String userName;
  final String userEmail;
  
  const FrontDeskScreen({
    super.key, 
    required this.churchName,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<FrontDeskScreen> createState() => _FrontDeskScreenState();
}

class FormFieldConfig {
  final String id;
  final String label;
  final bool required;
  final String fieldType; // 'text', 'dropdown', 'phone', 'email', 'textarea'
  final List<String>? options; // For dropdown fields
  final int order;
  
  FormFieldConfig({
    required this.id,
    required this.label,
    this.required = false,
    this.fieldType = 'text',
    this.options,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'required': required,
      'fieldType': fieldType,
      'options': options,
      'order': order,
    };
  }

  factory FormFieldConfig.fromMap(Map<String, dynamic> map) {
    return FormFieldConfig(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      required: map['required'] ?? false,
      fieldType: map['fieldType'] ?? 'text',
      options: List<String>.from(map['options'] ?? []),
      order: map['order'] ?? 0,
    );
  }
}

class _FrontDeskScreenState extends State<FrontDeskScreen> {
  // Database service
  final DatabaseMethods _databaseMethods = DatabaseMethods();
  
  // Form configuration (loaded from Firebase)
  List<FormFieldConfig> _formFields = [];
  
  // Active form data
  final List<Map<String, TextEditingController>> _formControllers = [];
  final List<Map<String, dynamic>> _formValues = [];
  final List<GlobalKey<FormState>> _formKeys = [];
  
  // Visitors list from Firebase
  List<Map<String, dynamic>> _visitors = [];
  
  // Loading states
  bool _isLoadingFormConfig = true;
  bool _isLoadingVisitors = true;
  
  // Editing state
  Map<String, dynamic>? _editingVisitor;
  String? _editingVisitorId;

  // Stream subscription
  StreamSubscription? _visitorsStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadFormConfiguration();
    _setupVisitorsStream();
  }

  @override
  void dispose() {
    _visitorsStreamSubscription?.cancel();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (var controllers in _formControllers) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _loadFormConfiguration() async {
    try {
      setState(() {
        _isLoadingFormConfig = true;
      });

      final config = await _databaseMethods.getFormConfiguration();
      
      if (config.isNotEmpty && config['fields'] != null) {
        // Load saved form configuration
        final fields = List<Map<String, dynamic>>.from(config['fields']);
        _formFields = fields.map((field) => FormFieldConfig.fromMap(field)).toList();
      } else {
        // Use default form fields
        _formFields = _getDefaultFormFields();
      }

      // Initialize a new form with the loaded configuration
      _initializeNewForm();
      
    } catch (e) {
      debugPrint('Error loading form configuration: $e');
      // Fallback to default fields
      _formFields = _getDefaultFormFields();
      _initializeNewForm();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFormConfig = false;
        });
      }
    }
  }

  List<FormFieldConfig> _getDefaultFormFields() {
    return [
      FormFieldConfig(
        id: 'name',
        label: 'Full Name', 
        required: true, 
        fieldType: 'text',
        order: 1,
      ),
      FormFieldConfig(
        id: 'areaOfResidence',
        label: 'Area of Residence', 
        required: false, 
        fieldType: 'text',
        order: 2,
      ),
      FormFieldConfig(
        id: 'email',
        label: 'Email Address', 
        required: false, 
        fieldType: 'email',
        order: 3,
      ),
      FormFieldConfig(
        id: 'phone',
        label: 'Mobile Number', 
        required: true, 
        fieldType: 'phone',
        order: 4,
      ),
      FormFieldConfig(
        id: 'nationality',
        label: 'Nationality', 
        required: false, 
        fieldType: 'text',
        order: 5,
      ),
      FormFieldConfig(
        id: 'interests',
        label: 'Area of Interest', 
        required: true, 
        fieldType: 'dropdown',
        options: [
          'Baptism',
          'Small group studies',
          'Ways to serve',
          'Joining as a member',
          'The good news of Jesus Christ',
          'Other'
        ],
        order: 6,
      ),
      FormFieldConfig(
        id: 'howDidYouHear',
        label: 'How did you hear about us?', 
        required: false, 
        fieldType: 'dropdown',
        options: [
          'Google',
          'Website',
          'Social Media',
          'Friend/Family',
          'Walk-in',
          'Event',
          'Other'
        ],
        order: 7,
      ),
      FormFieldConfig(
        id: 'notes',
        label: 'Additional Notes / Prayer Requests', 
        required: false, 
        fieldType: 'textarea',
        order: 8,
      ),
    ];
  }

  void _setupVisitorsStream() {
    setState(() {
      _isLoadingVisitors = true;
    });

    _visitorsStreamSubscription = _databaseMethods.visitorsStreamSimple().listen(
      (List<Visitor> visitors) {
        // Convert Visitor objects to Map<String, dynamic> for display
        final convertedVisitors = visitors.map((visitor) {
          return {
            'id': visitor.id,
            'name': visitor.name,
            'email': visitor.email,
            'phone': visitor.phone,
            'churchName': visitor.churchName,
            'visitDate': visitor.visitDate,
            'interests': visitor.interests.isNotEmpty ? visitor.interests.first : '',
            'notes': visitor.notes,
            'status': visitor.status,
            'followUpRequired': visitor.followUpRequired,
          };
        }).toList();
        
        if (mounted) {
          setState(() {
            _visitors = convertedVisitors;
            _isLoadingVisitors = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error in visitors stream: $error');
        if (mounted) {
          setState(() {
            _isLoadingVisitors = false;
          });
        }
      },
    );
  }

  void _initializeNewForm() {
    setState(() {
      _formKeys.add(GlobalKey<FormState>());
      
      // Initialize controllers for all form fields
      final controllers = <String, TextEditingController>{};
      for (var field in _formFields) {
        controllers[field.id] = TextEditingController();
      }
      _formControllers.add(controllers);
      
      // Initialize values for dropdowns
      final values = <String, dynamic>{};
      for (var field in _formFields.where((f) => f.fieldType == 'dropdown')) {
        values[field.id] = null;
      }
      _formValues.add(values);
    });
  }

  void _addNewForm() {
    _initializeNewForm();
  }

  void _removeForm(int index) {
    if (_formKeys.length > 1) {
      setState(() {
        _formKeys.removeAt(index);
        _formControllers.removeAt(index);
        _formValues.removeAt(index);
      });
    }
  }

  // Save form configuration to Firebase
  Future<void> _saveFormConfiguration() async {
    try {
      final fields = _formFields.map((field) => field.toMap()).toList();
      
      await _databaseMethods.saveFormConfiguration({
        'fields': fields,
        'updatedAt': DateTime.now(),
      });
      
      _showSuccessSnackbar('Form configuration saved successfully');
    } catch (e) {
      _showErrorSnackbar('Error saving form configuration: $e');
    }
  }

  // Edit form fields configuration
  void _editFormFields() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Form Fields'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _formFields.length; i++)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _formFields[i].label,
                                    decoration: const InputDecoration(
                                      labelText: 'Field Label',
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _formFields[i] = FormFieldConfig(
                                          id: _formFields[i].id,
                                          label: value,
                                          required: _formFields[i].required,
                                          fieldType: _formFields[i].fieldType,
                                          options: _formFields[i].options,
                                          order: _formFields[i].order,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: _formFields[i].required,
                                  onChanged: (value) {
                                    setState(() {
                                      _formFields[i] = FormFieldConfig(
                                        id: _formFields[i].id,
                                        label: _formFields[i].label,
                                        required: value ?? false,
                                        fieldType: _formFields[i].fieldType,
                                        options: _formFields[i].options,
                                        order: _formFields[i].order,
                                      );
                                    });
                                  },
                                ),
                                const Text('Required'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _formFields[i].fieldType,
                              decoration: const InputDecoration(
                                labelText: 'Field Type',
                              ),
                              items: const [
                                DropdownMenuItem(value: 'text', child: Text('text')),
                                DropdownMenuItem(value: 'email', child: Text('email')),
                                DropdownMenuItem(value: 'phone', child: Text('phone')),
                                DropdownMenuItem(value: 'textarea', child: Text('textarea')),
                                DropdownMenuItem(value: 'dropdown', child: Text('dropdown')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _formFields[i] = FormFieldConfig(
                                    id: _formFields[i].id,
                                    label: _formFields[i].label,
                                    required: _formFields[i].required,
                                    fieldType: value!,
                                    options: value == 'dropdown' 
                                      ? _formFields[i].options ?? ['Option 1', 'Option 2']
                                      : null,
                                    order: _formFields[i].order,
                                  );
                                });
                              },
                            ),
                            if (_formFields[i].fieldType == 'dropdown')
                              Column(
                                children: [
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: _formFields[i].options?.join(', '),
                                    decoration: const InputDecoration(
                                      labelText: 'Options (comma separated)',
                                      hintText: 'Option 1, Option 2, Option 3',
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _formFields[i] = FormFieldConfig(
                                          id: _formFields[i].id,
                                          label: _formFields[i].label,
                                          required: _formFields[i].required,
                                          fieldType: _formFields[i].fieldType,
                                          options: value.split(',').map((e) => e.trim()).toList(),
                                          order: _formFields[i].order,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _formFields.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Field'),
                    onPressed: () {
                      setState(() {
                        _formFields.add(FormFieldConfig(
                          id: 'field_${DateTime.now().millisecondsSinceEpoch}',
                          label: 'New Field ${_formFields.length + 1}',
                          required: false,
                          fieldType: 'text',
                          order: _formFields.length + 1,
                        ));
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Save configuration to Firebase
                  await _saveFormConfiguration();
                  
                  // Reinitialize forms with new field structure
                  _formKeys.clear();
                  _formControllers.clear();
                  _formValues.clear();
                  _initializeNewForm();
                  
                  // Update state
                  if (mounted) {
                    setState(() {});
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveVisitor(int formIndex) async {
    if (_formKeys[formIndex].currentState?.validate() ?? false) {
      // Validate required dropdown fields
      for (var field in _formFields) {
        if (field.required && field.fieldType == 'dropdown') {
          if (_formValues[formIndex][field.id] == null) {
            _showErrorSnackbar('Please select ${field.label.toLowerCase()}');
            return;
          }
        }
      }

      try {
        // Prepare visitor data for Firebase
        final visitorData = <String, dynamic>{
          'name': '',
          'phone': '',
          'email': '',
          'churchName': widget.churchName,
          'visitDate': DateTime.now(),
          'interests': [],
          'status': 'pending',
          'counselorPreference': '',
          'notes': '',
          'followUpRequired': false,
        };
        
        // Map form fields to visitor model fields
        for (var field in _formFields) {
          if (field.fieldType == 'dropdown') {
            final value = _formValues[formIndex][field.id] ?? 'Not specified';
            
            // Map to visitor model fields
            if (field.id == 'interests') {
              visitorData['interests'] = [value];
            } else {
              visitorData[field.id] = value;
            }
            
          } else {
            final controller = _formControllers[formIndex][field.id];
            final value = controller?.text.isNotEmpty == true 
                ? controller!.text 
                : field.required ? 'Not provided' : '';
            
            visitorData[field.id] = value;
          }
        }

        // Add additional metadata
        visitorData['recordedBy'] = widget.userName;
        visitorData['recordedByEmail'] = widget.userEmail;
        visitorData['recordedTime'] = DateFormat('h:mm a').format(DateTime.now());
        visitorData['recordedDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());

        // Save to Firebase using saveVisitor method
        await _databaseMethods.saveVisitor(visitorData);

        // Clear the form
        _clearForm(formIndex);

        _showSuccessSnackbar('Visitor recorded successfully');
        
      } catch (e) {
        _showErrorSnackbar('Error saving visitor: $e');
      }
    }
  }

  void _clearForm(int index) {
    _formKeys[index].currentState?.reset();
    for (var controller in _formControllers[index].values) {
      controller.clear();
    }
    for (var key in _formValues[index].keys) {
      _formValues[index][key] = null;
    }
  }

  Widget _buildFormField(int formIndex, FormFieldConfig field) {
    switch (field.fieldType) {
      case 'dropdown':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                labelText: '${field.label}${field.required ? ' *' : ''}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _formValues[formIndex][field.id],
                  isExpanded: true,
                  hint: Text('Select ${field.label.toLowerCase()}'),
                  items: field.options?.map((value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList() ?? [],
                  onChanged: (String? newValue) {
                    setState(() {
                      _formValues[formIndex][field.id] = newValue;
                    });
                  },
                ),
              ),
            ),
            if (field.options?.contains('Other') == true && 
                _formValues[formIndex][field.id] == 'Other')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  controller: TextEditingController(),
                  decoration: InputDecoration(
                    labelText: 'Specify other ${field.label.toLowerCase()}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        );
      
      case 'textarea':
        return TextFormField(
          controller: _formControllers[formIndex][field.id],
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.note),
          ),
          maxLines: 3,
          validator: field.required ? (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          } : null,
        );
      
      case 'email':
        return TextFormField(
          controller: _formControllers[formIndex][field.id],
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            hintText: 'email@example.com',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: field.required ? (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          } : null,
        );
      
      case 'phone':
        return TextFormField(
          controller: _formControllers[formIndex][field.id],
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            hintText: '+254 7XX XXX XXX',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: field.required ? (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          } : null,
        );
      
      default: // text
        return TextFormField(
          controller: _formControllers[formIndex][field.id],
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            border: const OutlineInputBorder(),
            prefixIcon: _getIconForField(field.label),
          ),
          validator: field.required ? (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          } : null,
        );
    }
  }

  void _editVisitor(int index) async {
    try {
      final visitor = _visitors[index];
      final visitorId = visitor['id'] as String;
      
      // Load full visitor data
      final fullVisitor = await _databaseMethods.getVisitorById(visitorId);
      
      if (fullVisitor == null) {
        _showErrorSnackbar('Visitor not found');
        return;
      }
      
      // Initialize form if empty
      if (_formControllers.isEmpty) {
        _initializeNewForm();
      }
      
      // Fill form with visitor data for editing
      for (var field in _formFields) {
        dynamic value;
        
        // Get value from Visitor object
        switch (field.id) {
          case 'name':
            value = fullVisitor.name;
            break;
          case 'phone':
            value = fullVisitor.phone;
            break;
          case 'email':
            value = fullVisitor.email;
            break;
          case 'interests':
            value = fullVisitor.interests.isNotEmpty ? fullVisitor.interests.first : '';
            break;
          case 'notes':
            value = fullVisitor.notes;
            break;
          default:
            // For other fields, check if they exist as additional data
            // You might need to store these as additional fields in your Visitor model
            value = null;
        }
        
        if (field.fieldType == 'dropdown') {
          if (value != null && _formValues.isNotEmpty) {
            _formValues[0][field.id] = value.toString();
          }
        } else {
          if (value != null && _formControllers.isNotEmpty) {
            final controller = _formControllers[0][field.id];
            if (controller != null) {
              controller.text = value.toString();
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _editingVisitor = visitor;
          _editingVisitorId = visitorId;
        });
      }
      
      _showSuccessSnackbar('Editing ${visitor['name'] ?? 'Visitor'}');
      
    } catch (e) {
      _showErrorSnackbar('Error loading visitor: $e');
    }
  }

  Future<void> _updateVisitor() async {
    if (_formKeys[0].currentState?.validate() ?? false) {
      try {
        final updates = <String, dynamic>{};
        
        for (var field in _formFields) {
          if (field.fieldType == 'dropdown') {
            updates[field.id] = _formValues[0][field.id] ?? 'Not specified';
          } else {
            final controller = _formControllers[0][field.id];
            updates[field.id] = controller?.text.isNotEmpty == true 
                ? controller!.text 
                : field.required ? 'Not provided' : '';
          }
        }
        
        // For interests field, convert to list
        if (updates.containsKey('interests')) {
          updates['interests'] = [updates['interests']];
        }
        
        updates['updatedAt'] = DateTime.now();
        updates['updatedBy'] = widget.userName;
        updates['updatedByEmail'] = widget.userEmail;
        
        await _databaseMethods.updateVisitor(_editingVisitorId!, updates);
        
        if (mounted) {
          setState(() {
            _editingVisitor = null;
            _editingVisitorId = null;
            _clearForm(0);
          });
        }
        
        _showSuccessSnackbar('Visitor updated successfully');
        
      } catch (e) {
        _showErrorSnackbar('Error updating visitor: $e');
      }
    }
  }

  Future<void> _deleteVisitor(int index) async {
    final visitor = _visitors[index];
    final visitorId = visitor['id'] as String;
    final visitorName = visitor['name'] as String? ?? 'Visitor';
    
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Visitor'),
        content: Text('Are you sure you want to delete $visitorName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        await _databaseMethods.deleteVisitor(visitorId);
        _showSuccessSnackbar('$visitorName deleted successfully');
      } catch (e) {
        _showErrorSnackbar('Error deleting visitor: $e');
      }
    }
  }

  void _showVisitorDetails(BuildContext context, Map<String, dynamic> visitor) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(visitor['name']?.toString() ?? 'Visitor Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Name', visitor['name']?.toString() ?? ''),
              if (visitor['phone']?.toString().isNotEmpty == true)
                _buildDetailItem('Phone', visitor['phone'].toString()),
              if (visitor['email']?.toString().isNotEmpty == true)
                _buildDetailItem('Email', visitor['email'].toString()),
              if (visitor['interests']?.toString().isNotEmpty == true)
                _buildDetailItem('Interests', visitor['interests'].toString()),
              if (visitor['notes']?.toString().isNotEmpty == true)
                _buildDetailItem('Notes', visitor['notes'].toString()),
              if (visitor['visitDate'] != null)
                _buildDetailItem('Visit Date', DateFormat('yyyy-MM-dd').format(visitor['visitDate'])),
              if (visitor['status']?.toString().isNotEmpty == true)
                _buildDetailItem('Status', visitor['status'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editVisitor(_visitors.indexOf(visitor));
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          theme: themeProvider.getThemeForRole('frontdesk'),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Front Desk - Visitor Management'),
              actions: [
                if (_editingVisitor != null)
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () {
                      setState(() {
                        _editingVisitor = null;
                        _editingVisitorId = null;
                        _clearForm(0);
                      });
                    },
                    tooltip: 'Cancel Edit',
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoadingVisitors ? null : () {
                    // Force refresh visitors
                    _setupVisitorsStream();
                  },
                  tooltip: 'Refresh visitors',
                ),
              ],
            ),
            body: _isLoadingFormConfig
                ? const Center(child: CircularProgressIndicator())
                : ResponsiveLayout(
                    mobile: _buildMobileLayout(),
                    tablet: _buildTabletLayout(),
                    desktop: _buildDesktopLayout(),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Forms Section
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFormsSection(),
          ),
        ),
        
        // Divider
        Container(
          height: 1,
          color: Colors.grey[300],
        ),
        
        // Visitors List Section
        Expanded(
          child: _buildVisitorList(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Forms Column
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildFormsSection(),
          ),
        ),
        
        // Divider
        Container(
          width: 1,
          color: Colors.grey[300],
        ),
        
        // Visitors List Column
        Expanded(
          flex: 1,
          child: _buildVisitorList(),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Forms Column
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_editingVisitor != null)
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.edit, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Editing: ${_editingVisitor!['name'] ?? 'Visitor'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _updateVisitor,
                              child: const Text('Update'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _buildFormsSection(),
                ],
              ),
            ),
          ),
        ),
        
        // Divider
        Container(
          width: 1,
          color: Colors.grey[300],
        ),
        
        // Visitors List Column
        Expanded(
          flex: 2,
          child: _buildVisitorList(),
        ),
      ],
    );
  }

  Widget _buildFormsSection() {
    if (_isLoadingFormConfig) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with Church and User info
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.churchName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Front Desk: ${widget.userName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _editFormFields,
                        tooltip: 'Edit Form Fields',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formKeys.length} active form${_formKeys.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Form'),
                        onPressed: _addNewForm,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Forms
          ...List.generate(_formKeys.length, (index) => _buildSingleForm(index)),
        ],
      ),
    );
  }

  Widget _buildSingleForm(int formIndex) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKeys[formIndex],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_add, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 10),
                      Text('Visitor Form ${formIndex + 1}', 
                           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_formKeys.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeForm(formIndex),
                      tooltip: 'Remove form',
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Dynamic form fields (sorted by order)
              ..._formFields
                .where((field) => field.fieldType != 'hidden')
                .map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildFormField(formIndex, field),
                )),
              
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save Visitor Record'),
                  onPressed: () => _saveVisitor(formIndex),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisitorList() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Visitors (${_visitors.length})', 
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (_visitors.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export'),
                      onPressed: () {},
                    ),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {},
                    tooltip: 'Filter',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingVisitors
                ? const Center(child: CircularProgressIndicator())
                : _visitors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 60, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No visitors recorded yet'),
                            const SizedBox(height: 8),
                            const Text('Start by adding a new visitor', 
                                 style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _visitors.length,
                        itemBuilder: (context, index) {
                          final visitor = _visitors[index];
                          final interest = visitor['interests'] ?? 'Not specified';
                          final visitDate = visitor['visitDate'] as DateTime? ?? DateTime.now();
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withAlpha(25),
                                child: Icon(
                                  Icons.person,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(visitor['name']?.toString() ?? 'Unknown'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (interest != 'Not specified')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        interest.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  if (visitor['phone']?.toString().isNotEmpty == true)
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            visitor['phone'].toString(),
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(visitDate),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const Spacer(),
                                      if (visitor['email']?.toString().isNotEmpty == true)
                                        const Icon(Icons.email, size: 12, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.visibility, size: 18),
                                        SizedBox(width: 8),
                                        Text('View Details'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editVisitor(index);
                                  } else if (value == 'delete') {
                                    _deleteVisitor(index);
                                  } else if (value == 'view') {
                                    _showVisitorDetails(context, visitor);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      )
    );
  }

  Icon? _getIconForField(String label) {
    if (label.toLowerCase().contains('name')) return const Icon(Icons.person);
    if (label.toLowerCase().contains('email')) return const Icon(Icons.email);
    if (label.toLowerCase().contains('phone')) return const Icon(Icons.phone);
    if (label.toLowerCase().contains('location') || label.toLowerCase().contains('residence')) {
      return const Icon(Icons.location_on);
    }
    if (label.toLowerCase().contains('nationality')) return const Icon(Icons.flag);
    if (label.toLowerCase().contains('interest')) return const Icon(Icons.category);
    if (label.toLowerCase().contains('hear')) return const Icon(Icons.info);
    if (label.toLowerCase().contains('note')) return const Icon(Icons.note);
    return const Icon(Icons.text_fields);
  }
}