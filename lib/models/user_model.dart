import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// In your user_model.dart
class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String churchName;
  final String churchId; // This is CRITICAL
  final String role;
  final String phone;
  final DateTime createdAt;
  final bool isActive;
  final DateTime? lastLogin;
  final List<String> permissions;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.churchName,
    required this.churchId, // Add this
    required this.role,
    required this.phone,
    required this.createdAt,
    required this.isActive,
    this.lastLogin,
    this.permissions = const [], required emailVerified,
  });

  // Add copyWith method
  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? phone, required bool emailVerified, required DateTime lastLogin, required String churchId, required String churchName, required role, required isActive, required List<String> permissions,
  }) {
    String finalChurchId = churchId; // Retain existing churchId
    return AppUser(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      churchName: churchName,
      churchId: finalChurchId, // Include in copyWith
      role: role,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      isActive: isActive,
      lastLogin: lastLogin,
      permissions: permissions, emailVerified: null,
    );
  }

  // Make sure to update fromJson and toJson methods
  factory AppUser.fromJson(Map<String, dynamic> json, String id) {
    return AppUser(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      churchName: json['churchName'] ?? '',
      churchId: json['finalChurchId'] ?? '', // Add this
      role: json['role'] ?? 'Front Desk',
      phone: json['phone'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isActive: json['isActive'] ?? true,
      lastLogin: json['lastLogin'] != null 
          ? (json['lastLogin'] as Timestamp).toDate()
          : null,
      permissions: List<String>.from(json['permissions'] ?? []), emailVerified: null,
    );
  }

  bool? get emailVerified => null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'churchName': churchName,
      'churchId': churchId, // Add this
      'role': role,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'lastLogin': lastLogin != null 
          ? Timestamp.fromDate(lastLogin!)
          : null,
      'permissions': permissions,
    };
  }
}

class Visitor {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String churchName;
  final DateTime visitDate;
  final List<String> interests;
  String status; // pending, scheduled, completed, cancelled
  final String? counselorPreference;
  final String notes;
  final bool followUpRequired;
  final String? churchId;
  final bool hasAppointment;

  Visitor({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.churchName,
    required this.visitDate,
    required this.interests,
    required this.status,
    this.counselorPreference,
    this.notes = '',
    this.followUpRequired = false,
    this.churchId,
    this.hasAppointment = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'churchName': churchName,
      'visitDate': visitDate,
      'interests': interests,
      'status': status,
      'counselorPreference': counselorPreference,
      'notes': notes,
      'followUpRequired': followUpRequired,
      'churchId': churchId,
      'hasAppointment': hasAppointment,
    };
  }

  static Visitor fromMap(Map<String, dynamic> map, String id) {
    return Visitor(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      churchName: map['churchName'] ?? '',
      visitDate: (map['visitDate'] as Timestamp).toDate(),
      interests: List<String>.from(map['interests'] ?? []),
      status: map['status'] ?? 'pending',
      counselorPreference: map['counselorPreference'],
      notes: map['notes'] ?? '',
      followUpRequired: map['followUpRequired'] ?? false,
      churchId: map['churchId'],
      hasAppointment: map['hasAppointment'] ?? false,
    );
  }
}

class Appointment {
  final String id;
  final Visitor visitor;
  final Counselor counselor;
  final DateTime date;
  final TimeOfDay time;
  String status; // scheduled, confirmed, in-progress, completed, cancelled
  final String notes;
  final DateTime createdAt;
  DateTime? completedAt;
  String? counselorNotes;
  final int duration; // in minutes
  final String location;
  final String? churchId;

  Appointment({
    required this.id,
    required this.visitor,
    required this.counselor,
    required this.date,
    required this.time,
    required this.status,
    required this.notes,
    required this.createdAt,
    this.completedAt,
    this.counselorNotes,
    required this.duration,
    required this.location,
    this.churchId,
  });

  Map<String, dynamic> toMap() {
    return {
      'visitorId': visitor.id,
      'counselorId': counselor.id,
      'date': date,
      'time': {'hour': time.hour, 'minute': time.minute},
      'status': status,
      'notes': notes,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'counselorNotes': counselorNotes,
      'duration': duration,
      'location': location,
      'churchId': churchId,
    };
  }
}

class Counselor {
  final String id;
  final String name;
  final String role;
  final Color color;
  final String email;
  final String phone;
  final String bio;
  final List<String> availability;
  final List<String> specialties;
  final String churchName;
  final String? churchId;
  final bool isActive;

  Counselor({
    required this.id,
    required this.name,
    required this.role,
    required this.color,
    required this.email,
    required this.phone,
    required this.bio,
    required this.availability,
    required this.specialties,
    required this.churchName,
    this.churchId,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'color': color.value.toRadixString(16),
      'email': email,
      'phone': phone,
      'bio': bio,
      'availability': availability,
      'specialties': specialties,
      'churchName': churchName,
      'churchId': churchId,
      'isActive': isActive,
    };
  }

  static Counselor fromMap(Map<String, dynamic> map, String id) {
    return Counselor(
      id: id,
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      color: _parseColor(map['color'] as String? ?? '#2196F3'),
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      bio: map['bio'] ?? '',
      availability: List<String>.from(map['availability'] ?? []),
      specialties: List<String>.from(map['specialties'] ?? []),
      churchName: map['churchName'] ?? '',
      churchId: map['churchId'],
      isActive: map['isActive'] ?? true,
    );
  }

  static Color _parseColor(String colorString) {
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
}