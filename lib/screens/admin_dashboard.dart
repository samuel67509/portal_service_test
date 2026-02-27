

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:portal_service_test/helpers/database_methods.dart';
import 'package:portal_service_test/models/user_model.dart';

class AdminDashboard extends StatefulWidget {
  final String adminChurchName;
  final String adminEmail;
  
  const AdminDashboard({
    super.key,
    required this.adminChurchName,
    required this.adminEmail,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  List<Visitor> visitors = [];
  List<Appointment> appointments = [];
  List<Counselor> counselors = [];
  List<AppUser> users = [];
  final DatabaseMethods _databaseMethods = DatabaseMethods();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _currentChurchName = 'Your Church';
  Map<String, dynamic> _dashboardStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentChurchName = widget.adminChurchName;
    _initializeData();
  }

  void _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load all data
      await _loadUsers();
      await _loadVisitors();
      await _loadAppointments();
      await _loadDashboardStats();

      // Set up real-time listeners
      _setupRealtimeListeners();
      
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final subscription = _databaseMethods.usersStream().first;
    final userList = await subscription;
      setState(() {
        users = userList;
      });
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _loadVisitors() async {
    try {
      final visitorList = await _databaseMethods.getAllVisitors();
      setState(() {
        visitors = visitorList;
      });
    } catch (e) {
      print('Error loading visitors: $e');
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final appointmentList = await _databaseMethods.getAllAppointments();
      setState(() {
        appointments = appointmentList;
      });
    } catch (e) {
      print('Error loading appointments: $e');
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await _databaseMethods.getDashboardStats();
      setState(() {
        _dashboardStats = stats;
      });
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  void _setupRealtimeListeners() {
    // Users stream
    _databaseMethods.usersStream().listen((userList) {
      if (mounted) {
        setState(() {
          users = userList;
        });
      }
    });

    // Visitors stream
    _databaseMethods.visitorsStreamSimple().listen((visitorList) {
      if (mounted) {
        setState(() {
          visitors = visitorList;
        });
        // Refresh stats when visitors change
        _loadDashboardStats();
      }
    });
  }

  List<String> _getAvailableRoles() {
    return [
      'admin',
      'frontdesk',
      'counselor',
      'pastor',
      'member'
    ];
  }

  List<String> _getDefaultPermissions(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return ['all'];
      case 'frontdesk':
        return ['view_visitors', 'add_visitors', 'edit_visitors', 'view_users'];
      case 'counselor':
        return ['view_visitors', 'view_appointments', 'manage_appointments'];
      case 'pastor':
        return ['view_visitors', 'view_appointments', 'view_users'];
      default:
        return ['view_profile'];
    }
  }

  void _showAddUserDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'member';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: _getAvailableRoles().map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
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
              try {
                final user = AppUser(
                  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  email: emailController.text,
                  churchName: _currentChurchName,
                  role: selectedRole,
                  phone: phoneController.text,
                  createdAt: DateTime.now(),
                  isActive: true,
                  permissions: _getDefaultPermissions(selectedRole), churchId: '', emailVerified: null,
                );

                await _databaseMethods.addUser(user);
                Navigator.pop(context);
                _showSuccessSnackbar('User added successfully');
                await _loadUsers();
              } catch (e) {
                _showErrorSnackbar('Error adding user: $e');
              }
            },
            child: const Text('Add User'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(AppUser user) {
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone);
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: _getAvailableRoles().map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
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
              try {
                final updates = {
                  'firstName': firstNameController.text,
                  'lastName': lastNameController.text,
                  'email': emailController.text,
                  'phone': phoneController.text,
                  'role': selectedRole,
                };

                await _databaseMethods.updateUser(user.id, updates);
                Navigator.pop(context);
                _showSuccessSnackbar('User updated successfully');
                await _loadUsers();
              } catch (e) {
                _showErrorSnackbar('Error updating user: $e');
              }
            },
            child: const Text('Update User'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String userId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
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

    if (shouldDelete == true) {
      try {
        await _databaseMethods.deleteUser(userId);
        _showWarningSnackbar('User deleted');
        await _loadUsers();
      } catch (e) {
        _showErrorSnackbar('Error deleting user: $e');
      }
    }
  }

  void _toggleUserStatus(String userId) async {
    try {
      final user = users.firstWhere((u) => u.id == userId);
      await _databaseMethods.updateUser(userId, {
        'isActive': !user.isActive,
      });
      _showSuccessSnackbar('User status updated');
      await _loadUsers();
    } catch (e) {
      _showErrorSnackbar('Error updating user status: $e');
    }
  }

  void _showAddVisitorDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Visitor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
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
              try {
                final visitorData = {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'email': emailController.text,
                  'churchName': _currentChurchName,
                  'visitDate': DateTime.now(),
                  'interests': [],
                  'status': 'pending',
                  'counselorPreference': '',
                  'notes': notesController.text,
                  'followUpRequired': false,
                };

                await _databaseMethods.saveVisitor(visitorData);
                Navigator.pop(context);
                _showSuccessSnackbar('Visitor added successfully');
                await _loadVisitors();
              } catch (e) {
                _showErrorSnackbar('Error adding visitor: $e');
              }
            },
            child: const Text('Add Visitor'),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(Visitor? visitor) {
    final visitorController = TextEditingController(text: visitor?.name ?? '');
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    Counselor? selectedCounselor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Appointment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visitor == null)
                TextFormField(
                  controller: visitorController,
                  decoration: const InputDecoration(labelText: 'Visitor Name'),
                ),
              FutureBuilder<List<Counselor>>(
                future: _databaseMethods.getAllCounselors(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return const Text('Error loading counselors');
                  }
                  
                  final counselors = snapshot.data!;
                  return DropdownButtonFormField<Counselor>(
                    decoration: const InputDecoration(labelText: 'Counselor'),
                    value: selectedCounselor,
                    items: counselors.map((counselor) {
                      return DropdownMenuItem(
                        value: counselor,
                        child: Text(counselor.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCounselor = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setState(() {
                            selectedTime = time;
                          });
                        }
                      },
                      child: Text(selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
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
              try {
                if (visitor == null && visitorController.text.isEmpty) {
                  _showErrorSnackbar('Please enter visitor name');
                  return;
                }
                if (selectedCounselor == null) {
                  _showErrorSnackbar('Please select a counselor');
                  return;
                }

                final appointmentData = {
                  'visitorId': visitor?.id ?? 'temp_visitor',
                  'counselorId': selectedCounselor!.id,
                  'date': selectedDate,
                  'time': {'hour': selectedTime.hour, 'minute': selectedTime.minute},
                  'status': 'scheduled',
                  'notes': notesController.text,
                  'duration': 60,
                  'location': 'Church Office',
                };

                await _databaseMethods.scheduleAppointment(appointmentData);
                Navigator.pop(context);
                _showSuccessSnackbar('Appointment scheduled successfully');
                await _loadAppointments();
              } catch (e) {
                _showErrorSnackbar('Error scheduling appointment: $e');
              }
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
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

  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
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

  void _onMenuTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  // Stat Card Widget
  Widget _StatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Visitor Card Widget
  Widget _VisitorCard({
    required Visitor visitor,
    required Function(Visitor) onSchedule,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withAlpha(25),
          child: Icon(
            Icons.person,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        title: Text(visitor.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visitor.phone.isNotEmpty)
              Text(visitor.phone),
            if (visitor.email.isNotEmpty)
              Text(visitor.email),
            Text(
              DateFormat('MMM d, yyyy').format(visitor.visitDate),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.schedule),
          onPressed: () => onSchedule(visitor),
        ),
      ),
    );
  }

  // User Card Widget
  Widget _UserCard({required AppUser user}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive ? Colors.green.withAlpha(25) : Colors.grey.withAlpha(25),
          child: Icon(
            Icons.person,
            color: user.isActive ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(user.firstName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Row(
              children: [
                Chip(
                  label: Text(user.role),
                  backgroundColor: Colors.blue.withAlpha(25),
                  labelStyle: TextStyle(color: Colors.blue),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(user.isActive ? 'Active' : 'Inactive'),
                  backgroundColor: user.isActive ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
                  labelStyle: TextStyle(color: user.isActive ? Colors.green : Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardOverview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingVisitors = _dashboardStats['pendingVisitors'] ?? 0;
    final totalUsers = _dashboardStats['totalUsers'] ?? 0;
    final todaysAppointments = _dashboardStats['todaysAppointments'] ?? 0;
    final upcomingAppointments = _dashboardStats['upcomingAppointments'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.church, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                _currentChurchName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dashboard Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage church visitors, appointments, and users',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _StatCard(
                title: 'Pending Visitors',
                value: pendingVisitors.toString(),
                icon: Icons.people,
                color: Colors.blue,
                onTap: () => _onMenuTap(1),
              ),
              _StatCard(
                title: "Today's Appointments",
                value: todaysAppointments.toString(),
                icon: Icons.today,
                color: Colors.green,
                onTap: () => _onMenuTap(2),
              ),
              _StatCard(
                title: 'Active Users',
                value: '$totalUsers',
                icon: Icons.supervised_user_circle,
                color: Colors.purple,
                onTap: () => _onMenuTap(4),
              ),
              _StatCard(
                title: 'Upcoming',
                value: upcomingAppointments.toString(),
                icon: Icons.schedule,
                color: Colors.orange,
                onTap: () => _onMenuTap(2),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent Visitors',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _onMenuTap(1),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (visitors.isEmpty)
                        const Center(child: Text('No visitors yet')),
                      ...visitors.take(3).map((visitor) => _VisitorCard(
                        visitor: visitor, 
                        onSchedule: (_) => _showScheduleDialog(visitor)
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent Users',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _onMenuTap(4),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (users.isEmpty)
                        const Center(child: Text('No users yet')),
                      ...users.take(3).map((user) => _UserCard(user: user)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Visitors',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Visitor'),
                onPressed: _showAddVisitorDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search visitors...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (visitors.isEmpty)
            const Center(child: Text('No visitors found'))
          else
            ..._filteredVisitors.map((visitor) => _VisitorCard(
              visitor: visitor,
              onSchedule: (_) => _showScheduleDialog(visitor),
            )),
        ],
      ),
    );
  }

  Widget _buildAppointmentsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointments',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Schedule Appointment'),
            onPressed: () => _showScheduleDialog(null),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (appointments.isEmpty)
            const Center(child: Text('No appointments scheduled'))
          else
            ...appointments.map((appointment) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(appointment.status).withAlpha(25),
                  child: Icon(
                    Icons.calendar_today,
                    color: _getStatusColor(appointment.status),
                    size: 20,
                  ),
                ),
                title: Text(appointment.visitor.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('With: ${appointment.counselor.name}'),
                    Text('${DateFormat('MMM d, yyyy').format(appointment.date)} at ${appointment.time.format(context)}'),
                    Chip(
                      label: Text(appointment.status),
                      backgroundColor: _getStatusColor(appointment.status).withAlpha(25),
                      labelStyle: TextStyle(color: _getStatusColor(appointment.status)),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appointment.status == 'scheduled')
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _showCompleteAppointmentDialog(appointment.id),
                      ),
                    if (appointment.status == 'scheduled')
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _cancelAppointment(appointment.id),
                      ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildCounselorsScreen() {
    return FutureBuilder<List<Counselor>>(
      future: _databaseMethods.getAllCounselors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error loading counselors: ${snapshot.error}'));
        }
        
        final counselors = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Counselors',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (counselors.isEmpty)
                const Center(child: Text('No counselors found'))
              else
                ...counselors.map((counselor) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: counselor.color.withAlpha(25),
                      child: Icon(
                        Icons.person,
                        color: counselor.color,
                        size: 20,
                      ),
                    ),
                    title: Text(counselor.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(counselor.role),
                        Text(counselor.email),
                        Text(counselor.phone),
                      ],
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserManagementScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'User Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
                onPressed: _showAddUserDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (users.isEmpty)
            const Center(child: Text('No users found'))
          else
            ...users.map((user) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.isActive ? Colors.green.withAlpha(25) : Colors.grey.withAlpha(25),
                  child: Icon(
                    Icons.person,
                    color: user.isActive ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                ),
                title: Text(user.firstName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email),
                    Row(
                      children: [
                        Chip(
                          label: Text(user.role),
                          backgroundColor: Colors.blue.withAlpha(25),
                          labelStyle: TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(user.isActive ? 'Active' : 'Inactive'),
                          backgroundColor: user.isActive ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
                          labelStyle: TextStyle(color: user.isActive ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditUserDialog(user),
                    ),
                    IconButton(
                      icon: Icon(
                        user.isActive ? Icons.toggle_on : Icons.toggle_off,
                        color: user.isActive ? Colors.green : Colors.grey,
                      ),
                      onPressed: () => _toggleUserStatus(user.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(user.id),
                    ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  void _showCompleteAppointmentDialog(String appointmentId) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Appointment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Counselor Notes'),
                maxLines: 3,
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
              try {
                await _databaseMethods.updateAppointment(appointmentId, {
                  'status': 'completed',
                  'completedAt': DateTime.now(),
                  'counselorNotes': notesController.text,
                });
                Navigator.pop(context);
                _showSuccessSnackbar('Appointment marked as completed');
                await _loadAppointments();
              } catch (e) {
                _showErrorSnackbar('Error completing appointment: $e');
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _cancelAppointment(String appointmentId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      try {
        await _databaseMethods.updateAppointment(appointmentId, {
          'status': 'cancelled',
        });
        _showWarningSnackbar('Appointment cancelled');
        await _loadAppointments();
      } catch (e) {
        _showErrorSnackbar('Error cancelling appointment: $e');
      }
    }
  }

  List<Visitor> get _filteredVisitors {
    if (_searchQuery.isEmpty) return visitors;
    return visitors.where((visitor) => 
      visitor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      visitor.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      visitor.phone.contains(_searchQuery)
    ).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'in-progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildDashboardOverview(),
      _buildVisitorsScreen(),
      _buildAppointmentsScreen(),
      _buildCounselorsScreen(),
      _buildUserManagementScreen(),
    ];

    final List<NavigationDestination> _navDestinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people),
        label: 'Visitors',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_today),
        label: 'Appointments',
      ),
      const NavigationDestination(
        icon: Icon(Icons.psychology),
        label: 'Counselors',
      ),
      const NavigationDestination(
        icon: Icon(Icons.manage_accounts),
        label: 'Users',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - $_currentChurchName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _pageController.jumpToPage(index);
        },
        destinations: _navDestinations,
      ),
    );
  }
}