import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:portal_service_test/models/user_model.dart';

class DatabaseMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Caching for better performance
  String? _cachedChurchId;
  String? _cachedUserId;
  Map<String, dynamic>? _cachedChurchSettings;
  
  // ============ CORE METHODS ============
  
  Future<String?> getCurrentUserId({bool forceRefresh = false}) async {
    if (_cachedUserId != null && !forceRefresh) {
      return _cachedUserId;
    }
    _cachedUserId = _auth.currentUser?.uid;
    return _cachedUserId;
  }
  
  Future<String?> getCurrentChurchId({bool forceRefresh = false}) async {
    if (_cachedChurchId != null && !forceRefresh) {
      return _cachedChurchId;
    }
    
    final userId = await getCurrentUserId();
    if (userId == null) return null;
    
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      final data = userDoc.data();
      _cachedChurchId = data != null ? data['churchId'] as String? : null;
      return _cachedChurchId;
    } catch (e) {
      print('Error getting church ID: $e');
      return null;
    }
  }
  
  Future<DocumentReference> get _churchRef async {
    final churchId = await getCurrentChurchId();
    if (churchId == null) throw Exception('No church ID found');
    return _firestore.collection('churches').doc(churchId);
  }
  
  // ============ OPTIMIZED USER MANAGEMENT ============
  
  Future<void> addUser(AppUser user) async {
  if (user.churchId.isEmpty) {
    throw Exception('No church ID provided');
  }

  final churchRef = _firestore.collection('churches').doc(user.churchId);
  final batch = _firestore.batch();

  final userData = {
    'firstName': user.firstName,
    'lastName': user.lastName,
    'email': user.email,
    'role': user.role,
    'phone': user.phone,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'isActive': user.isActive,
    'permissions': user.permissions,
    'churchId': user.churchId,
    'lastLogin': null,
    'searchableName': '${user.firstName.toLowerCase()} ${user.lastName.toLowerCase()}',
    'searchableEmail': user.email.toLowerCase(),
  };

  batch.set(churchRef.collection('users').doc(user.id), userData);

  batch.set(
    _firestore.collection('users').doc(user.id),
    {
      'email': user.email,
      'churchId': user.churchId,
      'role': user.role,
      'lastLogin': FieldValue.serverTimestamp(),
      'displayName': '${user.firstName} ${user.lastName}',
    },
    SetOptions(merge: true),
  );

  await batch.commit();
}

  
  Future<List<AppUser>> getAllUsers() async {
    try {
      final churchRef = await _churchRef;
      final snapshot = await churchRef
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map(_userFromDocument).whereType<AppUser>().toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }
  
  AppUser? _userFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    
    return AppUser(
      id: doc.id,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      churchName: data['churchName'] as String? ?? '',
      churchId: data['churchId'] ,
      role: data['role'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      permissions: List<String>.from(data['permissions'] ?? []), emailVerified: null,
    );
  }
  
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    final churchRef = await _churchRef;
    
    // Add searchable fields if name/email is being updated
    final updatedData = Map<String, dynamic>.from(updates);
    if (updates.containsKey('firstName') || updates.containsKey('lastName')) {
      final firstName = updates['firstName'] as String? ?? '';
      final lastName = updates['lastName'] as String? ?? '';
      updatedData['searchableName'] = '$firstName $lastName'.toLowerCase();
    }
    if (updates.containsKey('email')) {
      updatedData['searchableEmail'] = (updates['email'] as String).toLowerCase();
    }
    
    updatedData['updatedAt'] = FieldValue.serverTimestamp();
    
    await churchRef.collection('users').doc(userId).update(updatedData);
    
    // Also update root user collection if needed
    if (updates.containsKey('role') || updates.containsKey('isActive')) {
      await _firestore.collection('users').doc(userId).update({
        'updatedAt': FieldValue.serverTimestamp(),
        if (updates.containsKey('role')) 'role': updates['role'],
        if (updates.containsKey('isActive')) 'isActive': updates['isActive'],
      });
    }
  }
  
  Future<void> deleteUser(String userId) async {
    final churchRef = await _churchRef;
    final batch = _firestore.batch();
    
    // Delete from church users
    batch.delete(churchRef.collection('users').doc(userId));
    
    // Mark as deleted in root collection (soft delete)
    batch.update(
      _firestore.collection('users').doc(userId),
      {'deletedAt': FieldValue.serverTimestamp()},
    );
    
    // Optional: Delete user's appointments
    final appointments = await churchRef
        .collection('appointments')
        .where('counselorId', isEqualTo: userId)
        .get();
    
    for (final doc in appointments.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }
  
  Stream<List<AppUser>> usersStream() {
    return _firestore
        .collectionGroup('users')
        .where('churchId', isEqualTo: _cachedChurchId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(_userFromDocument)
            .whereType<AppUser>()
            .toList());
  }
  
  // ============ OPTIMIZED VISITOR MANAGEMENT ============
  
  Future<DocumentReference> saveVisitor(Map<String, dynamic> visitorData) async {
    final churchRef = await _churchRef;
    final visitorId = _firestore.collection('visitors').doc().id;
    final userId = await getCurrentUserId();
    
    final enrichedData = _addSearchableFields({
      ...visitorData,
      'id': visitorId,
      'churchId': (await getCurrentChurchId())!,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'new',
      'recordedBy': userId,
      'recordedAt': FieldValue.serverTimestamp(),
      'followUpRequired': visitorData['followUpRequired'] ?? false,
      'hasAppointment': false,
      'lastAppointmentDate': null,
    });
    
    await churchRef.collection('visitors').doc(visitorId).set(enrichedData);
    
    // Create notification for new visitor
    await _createNotification(
      type: 'new_visitor',
      title: 'New Visitor',
      message: '${visitorData['name']} visited today',
      data: {'visitorId': visitorId},
    );
    
    return churchRef.collection('visitors').doc(visitorId);
  }
  
  Future<List<Visitor>> getAllVisitors() async {
    try {
      final churchRef = await _churchRef;
      final snapshot = await churchRef
          .collection('visitors')
          .orderBy('visitDate', descending: true)
          .get();

      return snapshot.docs.map(_visitorFromDocument).whereType<Visitor>().toList();
    } catch (e) {
      print('Error getting visitors: $e');
      return [];
    }
  }
  
  Future<Visitor?> getVisitorById(String visitorId) async {
    try {
      final churchRef = await _churchRef;
      final doc = await churchRef.collection('visitors').doc(visitorId).get();
      
      if (doc.exists) {
        return _visitorFromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting visitor: $e');
      return null;
    }
  }
  
  Visitor? _visitorFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    
    return Visitor(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      churchName: data['churchName'] as String? ?? '',
      visitDate: (data['visitDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      interests: List<String>.from(data['interests'] ?? []),
      status: data['status'] as String? ?? 'pending',
      counselorPreference: data['counselorPreference'] as String?,
      notes: data['notes'] as String? ?? '',
      followUpRequired: data['followUpRequired'] as bool? ?? false,
      churchId: data['churchId'] as String?,
      hasAppointment: data['hasAppointment'] as bool? ?? false,
    );
  }
  
  Future<void> updateVisitor(String visitorId, Map<String, dynamic> updates) async {
    final churchRef = await _churchRef;
    
    final updatedData = Map<String, dynamic>.from(updates);
    updatedData['updatedAt'] = FieldValue.serverTimestamp();
    
    // Add searchable fields if updating searchable data
    if (updates.containsKey('name') || updates.containsKey('email') || updates.containsKey('phone')) {
      final searchableData = _addSearchableFields(updates);
      updatedData.addAll(searchableData);
    }
    
    await churchRef.collection('visitors').doc(visitorId).update(updatedData);
  }
  
  Future<void> deleteVisitor(String visitorId) async {
    final churchRef = await _churchRef;
    await churchRef.collection('visitors').doc(visitorId).delete();
  }
  
  Map<String, dynamic> _addSearchableFields(Map<String, dynamic> data) {
    final searchableData = <String, dynamic>{};
    
    if (data['name'] != null) {
      searchableData['searchableName'] = (data['name'] as String).toLowerCase();
    }
    if (data['email'] != null) {
      searchableData['searchableEmail'] = (data['email'] as String).toLowerCase();
    }
    if (data['phone'] != null) {
      searchableData['searchablePhone'] = (data['phone'] as String).replaceAll(RegExp(r'\D+'), '');
    }
    
    return searchableData;
  }
  
  Stream<List<Visitor>> visitorsStreamSimple() {
    return _firestore
        .collectionGroup('visitors')
        .where('churchId', isEqualTo: _cachedChurchId)
        .orderBy('visitDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(_visitorFromDocument)
            .whereType<Visitor>()
            .toList());
  }
  
  Future<List<Visitor>> searchVisitors(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final churchRef = await _churchRef;
      final lowercaseQuery = query.toLowerCase();
      
      final snapshot = await churchRef
          .collection('visitors')
          .where('searchableName', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('searchableName', isLessThan: '$lowercaseQuery\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs.map(_visitorFromDocument).whereType<Visitor>().toList();
    } catch (e) {
      print('Error searching visitors: $e');
      return [];
    }
  }
  
  Future<int> getTodaysVisitorsCount() async {
    try {
      final churchRef = await _churchRef;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      final snapshot = await churchRef
          .collection('visitors')
          .where('visitDate', isGreaterThanOrEqualTo: startOfDay)
          .where('visitDate', isLessThanOrEqualTo: endOfDay)
          .get();

      return snapshot.size;
    } catch (e) {
      print('Error getting today\'s visitors count: $e');
      return 0;
    }
  }
  
  // ============ OPTIMIZED APPOINTMENT MANAGEMENT ============
  
  Future<DocumentReference> scheduleAppointment(Map<String, dynamic> appointmentData) async {
    final churchRef = await _churchRef;
    final appointmentId = _firestore.collection('appointments').doc().id;
    final batch = _firestore.batch();
    
    final appointmentDoc = churchRef.collection('appointments').doc(appointmentId);
    
    batch.set(appointmentDoc, {
      ...appointmentData,
      'id': appointmentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'scheduled',
      'churchId': (await getCurrentChurchId())!,
    });
    
    // Update visitor to mark appointment scheduled
    if (appointmentData['visitorId'] != null) {
      batch.update(
        churchRef.collection('visitors').doc(appointmentData['visitorId'] as String),
        {
          'hasAppointment': true,
          'lastAppointmentDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    
    await batch.commit();
    
    // Create notification
    await _createNotification(
      type: 'new_appointment',
      title: 'New Appointment Scheduled',
      message: 'Appointment scheduled',
      data: {'appointmentId': appointmentId},
      userId: appointmentData['counselorId'] as String?,
    );
    
    return appointmentDoc;
  }
  
  Future<List<Appointment>> getAllAppointments() async {
    try {
      final churchRef = await _churchRef;
      final snapshot = await churchRef
          .collection('appointments')
          .orderBy('date', descending: false)
          .limit(100) // Limit to prevent too much data loading
          .get();

      final appointments = <Appointment>[];
      
      // Process appointments in batches to avoid too many async calls
      final visitorIds = <String>{};
      final counselorIds = <String>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final visitorId = data['visitorId'] as String?;
        final counselorId = data['counselorId'] as String?;
        
        if (visitorId != null) visitorIds.add(visitorId);
        if (counselorId != null) counselorIds.add(counselorId);
      }
      
      // Fetch all visitors and counselors in batch
      final visitorsFuture = _fetchVisitorsByIds(visitorIds.toList());
      final counselorsFuture = _fetchCounselorsByIds(counselorIds.toList());
      
      final results = await Future.wait([
        visitorsFuture,
        counselorsFuture,
      ]);
      
      final visitorsMap = results[0] as Map<String, Visitor>;
      final counselorsMap = results[1] as Map<String, Counselor>;
      
      // Build appointments
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final visitorId = data['visitorId'] as String?;
        final counselorId = data['counselorId'] as String?;
        
        final visitor = visitorId != null ? visitorsMap[visitorId] : null;
        final counselor = counselorId != null ? counselorsMap[counselorId] : null;
        
        if (visitor == null || counselor == null) continue;
        
        final timeData = data['time'] as Map<String, dynamic>? ?? {};
        
        appointments.add(Appointment(
          id: doc.id,
          visitor: visitor,
          counselor: counselor,
          date: (data['date'] as Timestamp).toDate(),
          time: TimeOfDay(
            hour: timeData['hour'] as int? ?? 0,
            minute: timeData['minute'] as int? ?? 0,
          ),
          status: data['status'] as String? ?? 'scheduled',
          notes: data['notes'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          completedAt: data['completedAt'] != null 
              ? (data['completedAt'] as Timestamp).toDate()
              : null,
          counselorNotes: data['counselorNotes'] as String?,
          duration: data['duration'] as int? ?? 60,
          location: data['location'] as String? ?? 'Church Office',
          churchId: data['churchId'] as String?,
        ));
      }
      
      return appointments;
    } catch (e) {
      print('Error getting appointments: $e');
      return [];
    }
  }
  
  Future<Map<String, Visitor>> _fetchVisitorsByIds(List<String> visitorIds) async {
    if (visitorIds.isEmpty) return {};
    
    try {
      final churchRef = await _churchRef;
      final snapshot = await churchRef
          .collection('visitors')
          .where(FieldPath.documentId, whereIn: visitorIds)
          .get();
      
      final visitors = <String, Visitor>{};
      for (final doc in snapshot.docs) {
        final visitor = _visitorFromDocument(doc);
        if (visitor != null) {
          visitors[doc.id] = visitor;
        }
      }
      return visitors;
    } catch (e) {
      print('Error fetching visitors by IDs: $e');
      return {};
    }
  }
  
  Future<void> updateAppointment(String appointmentId, Map<String, dynamic> updates) async {
    final churchRef = await _churchRef;
    
    final updatedData = Map<String, dynamic>.from(updates);
    updatedData['updatedAt'] = FieldValue.serverTimestamp();
    
    await churchRef.collection('appointments').doc(appointmentId).update(updatedData);
    
    // Create notification for status changes
    if (updates.containsKey('status')) {
      final status = updates['status'] as String;
      await _createNotification(
        type: 'appointment_${status}',
        title: 'Appointment $status',
        message: 'Appointment has been $status',
        data: {'appointmentId': appointmentId, 'status': status},
      );
    }
  }
  
  // ============ OPTIMIZED COUNSELOR MANAGEMENT ============
  
  Counselor? _counselorFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    
    return Counselor(
      id: doc.id,
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      color: _parseColor(data['color'] as String? ?? '#2196F3'),
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      availability: List<String>.from(data['availability'] ?? []),
      specialties: List<String>.from(data['specialties'] ?? []),
      churchName: data['churchName'] as String? ?? '',
      churchId: data['churchId'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
  
  Future<List<Counselor>> getAllCounselors() async {
    try {
      final churchRef = await _churchRef;
      final snapshot = await churchRef
          .collection('counselors')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs.map(_counselorFromDocument).whereType<Counselor>().toList();
    } catch (e) {
      print('Error getting counselors: $e');
      return [];
    }
  }
  
  Future<Counselor?> getCounselorById(String counselorId) async {
    try {
      final churchRef = await _churchRef;
      final doc = await churchRef.collection('counselors').doc(counselorId).get();
      
      if (doc.exists) {
        return _counselorFromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting counselor: $e');
      return null;
    }
  }
  
  Future<Map<String, Counselor>> _fetchCounselorsByIds(List<String> counselorIds) async {
    if (counselorIds.isEmpty) return {};
    
    try {
      final churchRef = await _churchRef;
      final snapshot = await churchRef
          .collection('counselors')
          .where(FieldPath.documentId, whereIn: counselorIds)
          .get();
      
      final counselors = <String, Counselor>{};
      for (final doc in snapshot.docs) {
        final counselor = _counselorFromDocument(doc);
        if (counselor != null) {
          counselors[doc.id] = counselor;
        }
      }
      return counselors;
    } catch (e) {
      print('Error fetching counselors by IDs: $e');
      return {};
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
  
  // ============ STATISTICS & ANALYTICS ============
  
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final churchRef = await _churchRef;
      final churchId = await getCurrentChurchId();
      if (churchId == null) return {};
      
      // Use individual queries instead of transaction for simplicity
      final usersQuery = churchRef.collection('users').where('isActive', isEqualTo: true);
      final visitorsQuery = churchRef.collection('visitors');
      churchRef.collection('appointments');
      
      // Get counts separately
      final usersSnapshot = await usersQuery.get();
      final visitorsSnapshot = await visitorsQuery.get();
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      
      // Today's visitors
      final todaysVisitorsSnapshot = await churchRef
          .collection('visitors')
          .where('visitDate', isGreaterThanOrEqualTo: startOfDay)
          .where('visitDate', isLessThan: tomorrow)
          .get();
      
      // Pending visitors
      final pendingVisitorsSnapshot = await churchRef
          .collection('visitors')
          .where('status', isEqualTo: 'new')
          .get();
      
      // Upcoming appointments
      final upcomingAppointmentsSnapshot = await churchRef
          .collection('appointments')
          .where('status', isEqualTo: 'scheduled')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .get();
      
      // Today's appointments
      final todaysAppointmentsSnapshot = await churchRef
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: tomorrow)
          .where('status', whereIn: ['scheduled', 'confirmed'])
          .get();
      
      return {
        'totalUsers': usersSnapshot.size,
        'totalVisitors': visitorsSnapshot.size,
        'todaysVisitors': todaysVisitorsSnapshot.size,
        'pendingVisitors': pendingVisitorsSnapshot.size,
        'upcomingAppointments': upcomingAppointmentsSnapshot.size,
        'todaysAppointments': todaysAppointmentsSnapshot.size,
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'totalUsers': 0,
        'totalVisitors': 0,
        'todaysVisitors': 0,
        'pendingVisitors': 0,
        'upcomingAppointments': 0,
        'todaysAppointments': 0,
      };
    }
  }
  
  // ============ NOTIFICATION SYSTEM ============
  
  Future<void> _createNotification({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String? userId,
  }) async {
    try {
      final churchRef = await _churchRef;
      final notificationId = _firestore.collection('notifications').doc().id;
      
      final notification = {
        'id': notificationId,
        'type': type,
        'title': title,
        'message': message,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'churchId': (await getCurrentChurchId())!,
        'targetUserId': userId,
      };
      
      if (userId == null) {
        // Send to all active users
        final users = await churchRef
            .collection('users')
            .where('isActive', isEqualTo: true)
            .get();
        
        final batch = _firestore.batch();
        for (final user in users.docs) {
          final userNotificationId = _firestore.collection('notifications').doc().id;
          batch.set(
            churchRef.collection('notifications').doc(userNotificationId),
            {
              ...notification,
              'userId': user.id,
            },
          );
        }
        await batch.commit();
      } else {
        await churchRef.collection('notifications').doc(notificationId).set(notification);
      }
    } catch (e) {
      print('Error creating notification: $e');
    }
  }
  
  // ============ FORM CONFIGURATION ============
  
  Future<void> saveFormConfiguration(Map<String, dynamic> config) async {
    final churchRef = await _churchRef;
    
    await churchRef.collection('config').doc('visitor_form').set({
      ...config,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': await getCurrentUserId(),
    }, SetOptions(merge: true));
  }
  
  Future<Map<String, dynamic>> getFormConfiguration() async {
    try {
      final churchRef = await _churchRef;
      final doc = await churchRef.collection('config').doc('visitor_form').get();
      
      return doc.data() ?? {};
    } catch (e) {
      print('Error getting form configuration: $e');
      return {};
    }
  }
  
  // ============ CHURCH SETTINGS ============
  
  Future<Map<String, dynamic>> getChurchSettings() async {
    if (_cachedChurchSettings != null) {
      return _cachedChurchSettings!;
    }
    
    try {
      final churchRef = await _churchRef;
      final doc = await churchRef.get();
      
      _cachedChurchSettings = doc.data() as Map<String, dynamic>?;
      return _cachedChurchSettings ?? {};
    } catch (e) {
      print('Error getting church settings: $e');
      return {};
    }
  }
  
  Future<void> updateChurchSettings(Map<String, dynamic> updates) async {
    final churchRef = await _churchRef;
    
    await churchRef.update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Clear cache
    _cachedChurchSettings = null;
  }
  
  // ============ BATCH OPERATIONS ============
  
  Future<void> clearCache() {
    _cachedChurchId = null;
    _cachedUserId = null;
    _cachedChurchSettings = null;
    return Future.value();
  }
}