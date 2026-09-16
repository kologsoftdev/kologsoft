import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kologsoft/models/smsModel.dart';

class SMSProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SMSRecord> _smsHistory = [];
  List<SMSTemplate> _templates = [];
  List<BirthdayReminder> _birthdayReminders = [];
  bool _isLoading = false;
  String? _error;

  List<SMSRecord> get smsHistory => _smsHistory;
  List<SMSTemplate> get templates => _templates;
  List<BirthdayReminder> get birthdayReminders => _birthdayReminders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Send Single SMS
  Future<bool> sendSingleSMS({
    required String companyId,
    required String branchId,
    required String staff,
    required String phoneNumber,
    required String message,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final smsRecord = SMSRecord(
        companyId: companyId,
        branchId: branchId,
        staff: staff,
        message: message,
        recipients: [phoneNumber],
        recipientCount: 1,
        type: 'single',
        status: 'pending',
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('sms_logs')
          .add(smsRecord.toMap());

      // TODO: Integrate with SMS service provider here
      // (Twilio, AWS SNS, Firebase Cloud Functions, etc.)

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Send Bulk SMS
  Future<bool> sendBulkSMS({
    required String companyId,
    required String branchId,
    required String staff,
    required List<String> phoneNumbers,
    required String message,
    required String filterType, // 'all', 'branch', 'customerType'
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final smsRecord = SMSRecord(
        companyId: companyId,
        branchId: branchId,
        staff: staff,
        message: message,
        recipients: phoneNumbers,
        recipientCount: phoneNumbers.length,
        type: 'bulk',
        status: 'scheduled',
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('sms_logs')
          .add(smsRecord.toMap());

      // TODO: Integrate with SMS service provider here

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Send Birthday Greeting
  Future<bool> sendBirthdayGreeting({
    required String companyId,
    required String branchId,
    required String staff,
    required String customerId,
    required String customerName,
    required String phoneNumber,
    required String message,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final smsRecord = SMSRecord(
        companyId: companyId,
        branchId: branchId,
        staff: staff,
        message: message,
        recipients: [phoneNumber],
        recipientCount: 1,
        type: 'birthday',
        customerId: customerId,
        status: 'sent',
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('sms_logs')
          .add(smsRecord.toMap());

      // Update birthday reminder
      final reminders = await _firestore
          .collection('birthday_reminders')
          .where('customerId', isEqualTo: customerId)
          .where('companyid', isEqualTo: companyId)
          .get();

      if (reminders.docs.isNotEmpty) {
        await reminders.docs.first.reference.update({
          'reminderSent': true,
          'sentDate': Timestamp.now(),
        });
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Send Seasonal Greeting
  Future<bool> sendSeasonalGreeting({
    required String companyId,
    required String branchId,
    required String staff,
    required List<String> phoneNumbers,
    required String message,
    required String season,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final smsRecord = SMSRecord(
        companyId: companyId,
        branchId: branchId,
        staff: staff,
        message: message,
        recipients: phoneNumbers,
        recipientCount: phoneNumbers.length,
        type: 'seasonal',
        season: season,
        status: 'scheduled',
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('sms_logs')
          .add(smsRecord.toMap());

      // TODO: Integrate with SMS service provider here

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch SMS History
  Future<void> fetchSMSHistory({
    required String companyId,
    String? filterType,
    int limit = 100,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      Query query = _firestore
          .collection('sms_logs')
          .where('companyid', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (filterType != null && filterType != 'all') {
        query = query.where('type', isEqualTo: filterType);
      }

      final snapshot = await query.get();

      _smsHistory = snapshot.docs
          .map((doc) => SMSRecord.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch Upcoming Birthdays
  Future<List<Map<String, dynamic>>> fetchUpcomingBirthdays({
    required String companyId,
    int daysAhead = 7,
  }) async {
    try {
      final today = DateTime.now();
      final futureDate = today.add(Duration(days: daysAhead));

      // Note: Firestore doesn't support date range queries directly
      // This fetches all and filters in-app
      final snapshot = await _firestore
          .collection('customers')
          .where('companyid', isEqualTo: companyId)
          .get();

      final upcomingBirthdays = snapshot.docs.where((doc) {
        final data = doc.data();
        if (data['dateofbirth'] == null) return false;

        DateTime birthDate;
        if (data['dateofbirth'] is Timestamp) {
          birthDate = (data['dateofbirth'] as Timestamp).toDate();
        } else {
          try {
            birthDate = DateTime.parse(data['dateofbirth'].toString());
          } catch (e) {
            return false;
          }
        }

        // Get this year's birthday
        final thisYearBirthday = DateTime(
          today.year,
          birthDate.month,
          birthDate.day,
        );

        // Check if birthday is upcoming
        return thisYearBirthday.isAfter(today) &&
            thisYearBirthday.isBefore(futureDate);
      }).toList();

      return upcomingBirthdays
          .map((doc) => {...doc.data(), 'docId': doc.id})
          .toList();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Create SMS Template
  Future<bool> createTemplate({
    required String companyId,
    required String name,
    required String message,
    required String category, // 'birthday', 'seasonal', 'general'
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final template = SMSTemplate(
        companyId: companyId,
        name: name,
        message: message,
        category: category,
        isActive: true,
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('sms_templates')
          .add(template.toMap());

      await fetchTemplates(companyId: companyId);
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch SMS Templates
  Future<void> fetchTemplates({required String companyId}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('sms_templates')
          .where('companyid', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      _templates = snapshot.docs
          .map((doc) => SMSTemplate.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete SMS Template
  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _firestore
          .collection('sms_templates')
          .doc(templateId)
          .update({'isActive': false});
      
      _templates.removeWhere((t) => t.id == templateId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Get SMS Statistics
  Future<Map<String, dynamic>> getSMSStatistics({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('sms_logs')
          .where('companyid', isEqualTo: companyId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      int totalSent = 0;
      int singleSMS = 0;
      int bulkSMS = 0;
      int birthdaySMS = 0;
      int seasonalSMS = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalSent += (data['recipientCount'] as int?) ?? 0;

        switch (data['type']) {
          case 'single':
            singleSMS++;
            break;
          case 'bulk':
            bulkSMS++;
            break;
          case 'birthday':
            birthdaySMS++;
            break;
          case 'seasonal':
            seasonalSMS++;
            break;
        }
      }

      return {
        'totalSent': totalSent,
        'campaigns': snapshot.docs.length,
        'single': singleSMS,
        'bulk': bulkSMS,
        'birthday': birthdaySMS,
        'seasonal': seasonalSMS,
      };
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return {};
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
