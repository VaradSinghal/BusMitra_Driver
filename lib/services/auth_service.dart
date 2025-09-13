import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current Firebase user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Login using driverId + password (from Firestore drivers collection)
  Future<bool> login(String driverId, String password) async {
    try {
      // Look up driver in Firestore
      final querySnapshot = await _firestore
          .collection('drivers')
          .where('driverId', isEqualTo: driverId)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false; // Driver not found
      }

      final driverData = querySnapshot.docs.first.data();
      final email = driverData['email'] ?? '$driverId@busmitra.com';

      try {
        // Try Firebase Auth login with email and password
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return true;
      } catch (e) {
        // If FirebaseAuth login fails, try to create the user first
        try {
          await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          return true;
        } catch (createError) {
          debugPrint('Firebase Auth login and create failed: $e, $createError');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Login failed: $e');
      return false;
    }
  }

  /// Get current driver's ID (from Firestore drivers collection)
  Future<String?> getCurrentDriverId() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      // First try to find by email
      var driverDoc = await _firestore
          .collection('drivers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      // If not found by email, try to find by extracting driverId from email
      if (driverDoc.docs.isEmpty) {
        final emailPrefix = user.email?.split('@')[0] ?? '';
        driverDoc = await _firestore
            .collection('drivers')
            .where('driverId', isEqualTo: emailPrefix)
            .limit(1)
            .get();
      }

      if (driverDoc.docs.isEmpty) {
        return null;
      }

      final driverId = driverDoc.docs.first.data()['driverId'];
      if (driverId == null || driverId.toString().isEmpty) {
        return null;
      }

      return driverId.toString();
    } catch (e) {
      debugPrint('Error getting driver ID: $e');
      return null;
    }
  }

  /// Get current driver Firestore data
  Future<Map<String, dynamic>?> getCurrentDriverData() async {
    final driverId = await getCurrentDriverId();
    if (driverId == null) {
      return null; // Return null if no driver ID
    }

    try {
      final driverDoc = await _firestore
          .collection('drivers')
          .where('driverId', isEqualTo: driverId)
          .limit(1)
          .get();

      if (driverDoc.docs.isEmpty) {
        return null; // Return null if driver data not found
      }

      return driverDoc.docs.first.data();
    } catch (e) {
      debugPrint('Error getting driver data: $e');
      return null;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}