import 'package:intl/intl.dart';

class SMSUtils {
  // Phone number validation
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove spaces and special characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Check if phone number is between 7 and 15 digits
    return cleaned.length >= 7 && cleaned.length <= 15;
  }

  // Format phone number
  static String formatPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleaned.isEmpty) return '';
    
    // Add country code if not present (Ghana example)
    if (!cleaned.startsWith('+') && !cleaned.startsWith('00')) {
      if (cleaned.startsWith('0')) {
        return '+233${cleaned.substring(1)}';
      } else if (cleaned.length == 9) {
        return '+233$cleaned';
      }
    }
    
    return cleaned;
  }

  // Calculate number of SMS based on message length
  static int calculateSMSCount(String message) {
    final length = message.length;
    
    if (length <= 160) return 1;
    if (length <= 306) return 2;
    if (length <= 459) return 3;
    if (length <= 612) return 4;
    
    return (length / 153).ceil();
  }

  // Get SMS cost estimate (customize based on your rates)
  static double calculateSMSCost({
    required int smsCount,
    required int recipientCount,
    double costPerSMS = 0.05, // $0.05 per SMS
  }) {
    return smsCount * recipientCount * costPerSMS;
  }

  // Format date for display
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }

  // Format time until birthday
  static String getTimeUntilBirthday(DateTime birthDate) {
    final today = DateTime.now();
    
    // Get this year's birthday
    DateTime thisYearBirthday;
    if (birthDate.month < today.month ||
        (birthDate.month == today.month && birthDate.day < today.day)) {
      // Birthday already passed this year
      thisYearBirthday = DateTime(today.year + 1, birthDate.month, birthDate.day);
    } else {
      thisYearBirthday = DateTime(today.year, birthDate.month, birthDate.day);
    }
    
    final difference = thisYearBirthday.difference(today).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference <= 7) return 'In $difference days';
    
    return 'In $difference days';
  }

  // Get customer age
  static int getCustomerAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }

  // Validate message content
  static String? validateMessage(String message) {
    if (message.isEmpty) {
      return 'Message cannot be empty';
    }
    
    if (message.length > 480) {
      return 'Message is too long (max 480 characters for 3 SMS)';
    }
    
    return null;
  }

  // Remove duplicate phone numbers
  static List<String> removeDuplicatePhones(List<String> phoneNumbers) {
    final Set<String> uniquePhones = {};
    final List<String> validPhones = [];
    
    for (final phone in phoneNumbers) {
      if (isValidPhoneNumber(phone)) {
        final formatted = formatPhoneNumber(phone);
        if (!uniquePhones.contains(formatted)) {
          uniquePhones.add(formatted);
          validPhones.add(formatted);
        }
      }
    }
    
    return validPhones;
  }

  // Parse recipient string (comma or newline separated)
  static List<String> parseRecipients(String recipientString) {
    final recipients = recipientString
        .split(RegExp(r'[,\n]'))
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty && isValidPhoneNumber(r))
        .map((r) => formatPhoneNumber(r))
        .toList();
    
    return removeDuplicatePhones(recipients);
  }

  // Generate SMS preview
  static String generatePreview(String message, {int maxLength = 50}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  // Get greeting type color
  static int getGreetingTypeColor(String type) {
    switch (type) {
      case 'single':
        return 0xFF2196F3; // Blue
      case 'bulk':
        return 0xFF4CAF50; // Green
      case 'birthday':
        return 0xFFE91E63; // Pink
      case 'seasonal':
        return 0xFFFFC107; // Amber
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  // Get greeting type icon
  static String getGreetingTypeIcon(String type) {
    switch (type) {
      case 'single':
        return '📱'; // Phone
      case 'bulk':
        return '📢'; // Broadcast
      case 'birthday':
        return '🎂'; // Cake
      case 'seasonal':
        return '🎉'; // Party
      default:
        return '💬'; // Chat
    }
  }

  // Get status color
  static int getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return 0xFF4CAF50; // Green
      case 'pending':
        return 0xFFFFC107; // Amber
      case 'failed':
        return 0xFFF44336; // Red
      case 'scheduled':
        return 0xFF2196F3; // Blue
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  // Check if message contains template variables
  static bool hasTemplateVariables(String message) {
    return message.contains('{{') && message.contains('}}');
  }

  // Get template variables from message
  static List<String> extractTemplateVariables(String message) {
    final regex = RegExp(r'{{(\w+)}}');
    final matches = regex.allMatches(message);
    return matches.map((m) => m.group(1)!).toList();
  }

  // Replace template variables
  static String replaceTemplateVariables(
    String message,
    Map<String, String> variables,
  ) {
    String result = message;
    variables.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    return result;
  }

  // Get SMS character encoding
  static String getSMSEncoding(String message) {
    final hasUnicode = !RegExp(r'^[\x00-\x7F]*$').hasMatch(message);
    return hasUnicode ? 'UTF-16' : 'GSM 7-bit';
  }

  // Estimate send time for bulk SMS
  static String estimateSendTime({
    required int recipientCount,
    int smsPerSecond = 20,
  }) {
    final seconds = (recipientCount / smsPerSecond).ceil();
    
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).ceil();
      return '$minutes minute${minutes > 1 ? 's' : ''}';
    } else {
      final hours = (seconds / 3600).ceil();
      return '$hours hour${hours > 1 ? 's' : ''}';
    }
  }

  // Get next birthday
  static String getUpcomingBirthdayMonth() {
    final today = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return months[today.month - 1];
  }

  // Format SMS statistics
  static String formatSMSStatistics(Map<String, dynamic> stats) {
    final buffer = StringBuffer();
    
    buffer.writeln('📊 SMS Statistics');
    buffer.writeln('─────────────────');
    buffer.writeln('Total Sent: ${stats['totalSent'] ?? 0}');
    buffer.writeln('Campaigns: ${stats['campaigns'] ?? 0}');
    buffer.writeln('Single: ${stats['single'] ?? 0}');
    buffer.writeln('Bulk: ${stats['bulk'] ?? 0}');
    buffer.writeln('Birthday: ${stats['birthday'] ?? 0}');
    buffer.writeln('Seasonal: ${stats['seasonal'] ?? 0}');
    
    return buffer.toString();
  }

  // Check if phone is likely active (basic validation)
  static bool isLikelyActivePhone(String phoneNumber) {
    // This is a simple check - can be enhanced with ML models
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check for common inactive patterns
    if (cleaned.replaceAll(RegExp(r'0'), '').isEmpty) return false;
    if (cleaned.replaceAll(cleaned[0], '').isEmpty) return false;
    
    return true;
  }

  // Generate daily birthday report
  static String generateDailyBirthdayReport(
    List<Map<String, dynamic>> birthdays,
  ) {
    if (birthdays.isEmpty) {
      return 'No birthdays today';
    }

    final buffer = StringBuffer();
    buffer.writeln('🎂 Today\'s Birthdays');
    buffer.writeln('───────────────────');
    
    for (final birthday in birthdays) {
      buffer.writeln('${birthday['name']} - ${birthday['contact']}');
    }
    
    return buffer.toString();
  }
}
