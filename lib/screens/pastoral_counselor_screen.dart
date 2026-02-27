
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:portal_service_test/models/user_model.dart';
import 'package:portal_service_test/theme/theme_provider.dart';
import 'package:portal_service_test/widgets/responsive_layout.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class PastoralCounselorScreen extends StatefulWidget {
  final String churchName;
  final String counselorEmail;
  final String role;

  const PastoralCounselorScreen({
    super.key,
    required this.churchName,
    required this.counselorEmail,
    required this.role, required String userRole,
  });

  @override
  State<PastoralCounselorScreen> createState() => _PastoralCounselorScreenState();
}

class _PastoralCounselorScreenState extends State<PastoralCounselorScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Appointment> _appointments = [];
  String? _counselorId;
  String? _churchId;
  AppUser? _currentUser;
  Counselor? _currentCounselor;
  String _selectedFilter = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      _counselorId = user.uid;
      
      // Get user data
      await _loadCurrentUser();
      
      // Load appointments
      await _loadAppointments();
      
      // Setup real-time listener
      _setupAppointmentsStream();
      
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userDoc = await _firestore
      .collection('users')
      .doc(_counselorId)
      .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          _currentUser = AppUser.fromJson(userData, userDoc.id);
          _churchId = userData['churchId'] as String?;
        });
        
        // Load counselor details
        await _loadCounselorDetails();
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadCounselorDetails() async {
    try {
      if (_churchId == null) return;
      
      final snapshot = await _firestore
          .collection('churches')
          .doc(_churchId)
          .collection('counselors')
          .where('userId', isEqualTo: _counselorId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        
        setState(() {
          _currentCounselor = Counselor(
            id: doc.id,
            name: data['name'] as String? ?? _currentUser?.firstName ?? '',
            role: data['role'] as String? ?? 'Counselor',
            color: _parseColor(data['color'] as String? ?? '#2196F3'),
            email: data['email'] as String? ?? _currentUser?.email ?? '',
            phone: data['phone'] as String? ?? _currentUser?.phone ?? '',
            bio: data['bio'] as String? ?? '',
            availability: List<String>.from(data['availability'] ?? []),
            specialties: List<String>.from(data['specialties'] ?? []),
            churchName: data['churchName'] as String? ?? widget.churchName,
          );
        });
      }
    } catch (e) {
      print('Error loading counselor details: $e');
    }
  }

  Future<void> _loadAppointments() async {
    try {
      if (_churchId == null || _counselorId == null) return;
      
      final snapshot = await _firestore
          .collection('churches')
          .doc(_churchId)
          .collection('appointments')
          .where('counselorId', isEqualTo: _counselorId)
          .orderBy('date', descending: false)
          .get();

      final appointments = <Appointment>[];
      
      for (final doc in snapshot.docs) {
        final appointment = await _mapToAppointment(doc);
        if (appointment != null) {
          appointments.add(appointment);
        }
      }
      
      setState(() => _appointments = appointments);
    } catch (e) {
      print('Error loading appointments: $e');
    }
  }

  Future<Appointment?> _mapToAppointment(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Get visitor data
      final visitorId = data['visitorId'] as String?;
      if (visitorId == null) return null;
      
      final visitorDoc = await _firestore
          .collection('churches')
          .doc(_churchId)
          .collection('visitors')
          .doc(visitorId)
          .get();
      
      if (!visitorDoc.exists) return null;
      
      final visitorData = visitorDoc.data()!;
      final visitor = Visitor(
        id: visitorDoc.id,
        name: visitorData['name'] as String? ?? '',
        phone: visitorData['phone'] as String? ?? '',
        email: visitorData['email'] as String? ?? '',
        churchName: visitorData['churchName'] as String? ?? widget.churchName,
        visitDate: (visitorData['visitDate'] as Timestamp).toDate(),
        interests: List<String>.from(visitorData['interests'] ?? []),
        status: data['status'] as String? ?? 'scheduled',
        counselorPreference: visitorData['counselorPreference'] as String?,
        notes: visitorData['notes'] as String? ?? '',
        followUpRequired: visitorData['followUpRequired'] as bool? ?? false,
      );
      
      // Get counselor data
      final counselor = _currentCounselor ?? Counselor(
        id: _counselorId!,
        name: _currentUser?.firstName ?? 'Unknown Counselor',
        role: 'Counselor',
        color: Colors.blue,
        email: _currentUser?.email ?? '',
        phone: _currentUser?.phone ?? '',
        bio: '',
        availability: [],
        specialties: [],
        churchName: widget.churchName,
      );
      
      // Parse time
      final timeData = data['time'] as Map<String, dynamic>? ?? {};
      final time = TimeOfDay(
        hour: timeData['hour'] as int? ?? 0,
        minute: timeData['minute'] as int? ?? 0,
      );
      
      return Appointment(
        id: doc.id,
        visitor: visitor,
        counselor: counselor,
        date: (data['date'] as Timestamp).toDate(),
        time: time,
        status: data['status'] as String? ?? 'scheduled',
        notes: data['notes'] as String? ?? '',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        completedAt: data['completedAt'] != null 
            ? (data['completedAt'] as Timestamp).toDate()
            : null,
        counselorNotes: data['counselorNotes'] as String?,
        duration: data['duration'] as int? ?? 60,
        location: data['location'] as String? ?? 'Church Office',
      );
    } catch (e) {
      print('Error mapping appointment: $e');
      return null;
    }
  }

  void _setupAppointmentsStream() {
    if (_churchId == null || _counselorId == null) return;
    
    _firestore
        .collection('churches')
        .doc(_churchId)
        .collection('appointments')
        .where('counselorId', isEqualTo: _counselorId)
        .orderBy('date', descending: false)
        .snapshots()
        .listen((snapshot) async {
          final appointments = <Appointment>[];
          
          for (final doc in snapshot.docs) {
            final appointment = await _mapToAppointment(doc);
            if (appointment != null) {
              appointments.add(appointment);
            }
          }
          
          if (mounted) {
            setState(() => _appointments = appointments);
          }
        });
  }

  Future<void> _markAppointmentAsComplete(Appointment appointment) async {
    try {
      if (_churchId == null) return;
      
      await _firestore
          .collection('churches')
          .doc(_churchId)
          .collection('appointments')
          .doc(appointment.id)
          .update({
            'status': 'completed',
            'completedAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
      
      // Also update visitor status
      await _firestore
          .collection('churches')
          .doc(_churchId)
          .collection('visitors')
          .doc(appointment.visitor.id)
          .update({
            'status': 'completed',
            'updatedAt': Timestamp.now(),
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Appointment marked as completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update appointment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAppointmentNotes(String appointmentId, String notes) async {
    try {
      if (_churchId == null) return;
      
      await _firestore
          .collection('churches')
          .doc(_churchId)
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'counselorNotes': notes,
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
      print('Error updating appointment notes: $e');
    }
  }

  Future<void> _rescheduleAppointment(String appointmentId, DateTime newDate, TimeOfDay newTime) async {
    try {
      if (_churchId == null) return;
      
      await _firestore
          .collection('churches')
          .doc(_churchId)
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'date': Timestamp.fromDate(newDate),
            'time': {'hour': newTime.hour, 'minute': newTime.minute},
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
      print('Error rescheduling appointment: $e');
      rethrow;
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        colorString = colorString.replaceFirst('#', '');
        if (colorString.length == 6) {
          colorString = 'FF$colorString';
        }
        final colorInt = int.parse(colorString, radix: 16);
        return Color(colorInt);
      }
    } catch (e) {
      print('Error parsing color: $e');
    }
    return Colors.blue;
  }

  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDay = DateTime(date.year, date.month, date.day);
    
    if (appointmentDay == today) return 'Today';
    if (appointmentDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (appointmentDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
      case 'confirmed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.getThemeForRole('pastoral_counselor');
        
        return Theme(
          data: theme,
          child: Scaffold(
            appBar: _buildAppBar(),
            body: SafeArea(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ResponsiveLayout(
                      mobile: _buildMobileLayout(context),
                      tablet: _buildTabletLayout(context),
                      desktop: _buildDesktopLayout(context),
                    ),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Counseling Appointments'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadAppointments,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: _showNotifications,
          tooltip: 'Notifications',
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildProfileHeader(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatsCard(context),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildFilterChips(),
        ),
        Expanded(child: _buildAppointmentsList()),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 250,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildProfileCard(context),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildStatsCard(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildFilterChips(),
              ),
              Expanded(child: _buildAppointmentsList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 280,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: _buildProfileCard(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildStatsCard(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(child: _buildFilterChips()),
                    const SizedBox(width: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
              Expanded(child: _buildAppointmentsList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(
                Icons.person,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentCounselor?.name ?? _currentUser?.firstName ?? 'Counselor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentCounselor?.role ?? widget.role,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(
                Icons.person,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentCounselor?.name ?? _currentUser?.firstName ?? 'Counselor',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              _currentCounselor?.role ?? widget.role,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            if (_currentCounselor?.email != null) ...[
              Text(
                _currentCounselor!.email,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final upcomingCount = _appointments.where((apt) => 
        apt.status == 'scheduled' || apt.status == 'confirmed').length;
    final completedCount = _appointments.where((apt) => 
        apt.status == 'completed').length;
    final today = DateTime.now();
    final todaysCount = _appointments.where((apt) => 
        apt.date.year == today.year && 
        apt.date.month == today.month && 
        apt.date.day == today.day).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Today', todaysCount, Colors.blue),
                _buildStatItem('Upcoming', upcomingCount, Colors.orange),
                _buildStatItem('Completed', completedCount, Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Divider(),
            const SizedBox(height: 8),
            Text(
              'Total Appointments: ${_appointments.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final upcomingCount = _appointments.where((apt) => 
        apt.status == 'scheduled' || apt.status == 'confirmed').length;
    final completedCount = _appointments.where((apt) => 
        apt.status == 'completed').length;
    final today = DateTime.now();
    final todaysCount = _appointments.where((apt) => 
        apt.date.year == today.year && 
        apt.date.month == today.month && 
        apt.date.day == today.day).length;

    final filters = [
      {'label': 'All', 'value': 'all', 'count': _appointments.length},
      {'label': 'Today', 'value': 'today', 'count': todaysCount},
      {'label': 'Upcoming', 'value': 'upcoming', 'count': upcomingCount},
      {'label': 'Completed', 'value': 'completed', 'count': completedCount},
    ];

    return Wrap(
      spacing: 8,
      children: filters.map((filter) {
        return FilterChip(
          label: Text('${filter['label']} (${filter['count']})'),
          selected: _selectedFilter == filter['value'],
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedFilter = filter['value'] as String);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          icon: Icon(Icons.download, size: 18),
          label: Text('Export'),
          onPressed: _exportAppointments,
        ),
        SizedBox(width: 8),
        ElevatedButton.icon(
          icon: Icon(Icons.add, size: 18),
          label: Text('New Appointment'),
          onPressed: _createNewAppointment,
        ),
      ],
    );
  }

  Widget _buildAppointmentsList() {
    final filteredAppointments = _appointments.where((apt) {
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'today') {
        final today = DateTime.now();
        return apt.date.year == today.year && 
               apt.date.month == today.month && 
               apt.date.day == today.day;
      }
      if (_selectedFilter == 'upcoming') {
        return apt.status == 'scheduled' || apt.status == 'confirmed';
      }
      if (_selectedFilter == 'completed') {
        return apt.status == 'completed';
      }
      return true;
    }).toList();

    if (filteredAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No appointments found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            if (_selectedFilter != 'all') ...[
              SizedBox(height: 8),
              Text(
                'Try changing your filter',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredAppointments.length,
      itemBuilder: (context, index) {
        final apt = filteredAppointments[index];
        return _buildAppointmentCard(context, apt);
      },
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Appointment appointment) {
    final statusColor = _getStatusColor(appointment.status);
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.visitor.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        appointment.visitor.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              appointment.notes.isNotEmpty 
                  ? appointment.notes 
                  : 'No additional notes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  _getFormattedDate(appointment.date),
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  _formatTime(appointment.time),
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.visibility, size: 16),
                    label: Text('Details'),
                    onPressed: () => _showAppointmentDetails(appointment),
                  ),
                ),
                SizedBox(width: 8),
                if (appointment.status == 'scheduled' || appointment.status == 'confirmed')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.check_circle, size: 16),
                      label: Text('Complete'),
                      onPressed: () => _markAppointmentAsComplete(appointment),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentDetails(Appointment appointment) {
    TextEditingController notesController = TextEditingController(
      text: appointment.counselorNotes ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appointment.visitor.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Appointment Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow('Date', _getFormattedDate(appointment.date)),
                _buildDetailRow('Time', _formatTime(appointment.time)),
                _buildDetailRow('Location', appointment.location),
                _buildDetailRow('Duration', '${appointment.duration} minutes'),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 16),
                Text(
                  'Visitor Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow('Email', appointment.visitor.email),
                _buildDetailRow('Phone', appointment.visitor.phone),
                _buildDetailRow('Interests', appointment.visitor.interests.join(', ')),
                if (appointment.visitor.notes.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    'Visitor Notes:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(appointment.visitor.notes),
                ],
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 16),
                Text(
                  'Counselor Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Add your notes here...',
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRescheduleDialog(appointment),
                        child: Text('Reschedule'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _updateAppointmentNotes(appointment.id, notesController.text);
                          Navigator.pop(context);
                        },
                        child: Text('Save Notes'),
                      ),
                    ),
                  ],
                ),
                if (appointment.status != 'completed') ...[
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.check_circle),
                      label: Text('Mark as Completed'),
                      onPressed: () async {
                        await _updateAppointmentNotes(appointment.id, notesController.text);
                        await _markAppointmentAsComplete(appointment);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not specified',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(Appointment appointment) {
    DateTime selectedDate = appointment.date;
    TimeOfDay selectedTime = appointment.time;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reschedule Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Select Date'),
                subtitle: Text('${selectedDate.year}-${selectedDate.month}-${selectedDate.day}'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) {
                    selectedDate = date;
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.access_time),
                title: Text('Select Time'),
                subtitle: Text(_formatTime(selectedTime)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) {
                    selectedTime = time;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _rescheduleAppointment(appointment.id, selectedDate, selectedTime);
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Appointment rescheduled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reschedule: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Reschedule'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNotifications() async {
    // TODO: Implement notifications view
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notifications'),
        content: Text('No new notifications'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAppointments() async {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export feature coming soon'),
      ),
    );
  }

  Future<void> _createNewAppointment() async {
    // TODO: Implement new appointment creation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New appointment feature coming soon'),
      ),
    );
  }
}