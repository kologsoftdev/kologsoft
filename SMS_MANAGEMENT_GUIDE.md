# SMS Management Module - Integration Guide

## Overview
The SMS Management module provides a comprehensive solution for sending SMS messages to customers with the following capabilities:

- **Single SMS**: Send SMS to individual customers
- **Bulk SMS**: Send SMS to multiple customers with filtering options
- **Birthday Greetings**: Automated birthday notifications
- **Seasonal Greetings**: Holiday and seasonal messages
- **SMS History**: Track all sent messages and campaigns

## Project Structure

### Files Created

1. **sms_management.dart** - Main UI module with 4 tabs
   - SendSMSPage: Single & Bulk SMS sending
   - BirthdayGreetingsPage: Birthday automation
   - SeasonalGreetingsPage: Holiday messages
   - SMSHistoryPage: Message logs and history

2. **smsModel.dart** - Data models
   - `SMSRecord`: SMS log record
   - `SMSTemplate`: Reusable message templates
   - `BirthdayReminder`: Birthday tracking

3. **SMSProvider.dart** - State management using Provider pattern
   - Handles all SMS operations
   - Firestore integration
   - Statistics and analytics

## Database Schema

### Collections Required

#### 1. sms_logs
```json
{
  "companyid": "string",
  "branchid": "string",
  "staff": "string",
  "message": "string",
  "recipients": ["phone1", "phone2"],
  "recipientCount": "number",
  "type": "single|bulk|birthday|seasonal",
  "season": "string (optional)",
  "customerId": "string (optional)",
  "status": "pending|sent|failed|scheduled",
  "createdAt": "timestamp",
  "updatedAt": "timestamp (optional)"
}
```

#### 2. sms_templates
```json
{
  "companyid": "string",
  "name": "string",
  "message": "string",
  "category": "birthday|seasonal|general",
  "isActive": "boolean",
  "createdAt": "timestamp"
}
```

#### 3. birthday_reminders
```json
{
  "customerId": "string",
  "customerName": "string",
  "customerPhone": "string",
  "companyid": "string",
  "branchid": "string",
  "birthDate": "date",
  "reminderSent": "boolean",
  "sentDate": "timestamp (optional)",
  "createdAt": "timestamp"
}
```

#### 4. customers (Update Required)
Add the following field to your existing customers collection:
```json
{
  "dateofbirth": "timestamp" // Required for birthday features
}
```

## Setup Instructions

### Step 1: Add Dependencies to pubspec.yaml

```yaml
dependencies:
  # Your existing dependencies...
  cloud_firestore: ^4.9.0
  flutter: ^3.0.0
  intl: ^0.19.0
  provider: ^6.0.0
```

### Step 2: Create Firestore Indexes

In Firebase Console, create the following composite indexes:

**Index 1: SMS Logs by Company and Date**
- Collection: `sms_logs`
- Fields: `companyid` (Ascending), `createdAt` (Descending)

**Index 2: Customers by Company and Birth Date**
- Collection: `customers`
- Fields: `companyid` (Ascending), `dateofbirth` (Ascending)

**Index 3: SMS Logs with Type Filter**
- Collection: `sms_logs`
- Fields: `companyid` (Ascending), `type` (Ascending), `createdAt` (Descending)

### Step 3: Set Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // SMS Logs - Staff can write, company admins can read
    match /sms_logs/{document=**} {
      allow write: if request.auth != null;
      allow read: if request.auth != null && 
                     resource.data.companyid == request.auth.token.companyid;
    }

    // SMS Templates
    match /sms_templates/{document=**} {
      allow read, write: if request.auth != null && 
                           resource.data.companyid == request.auth.token.companyid;
    }

    // Birthday Reminders
    match /birthday_reminders/{document=**} {
      allow read, write: if request.auth != null && 
                           resource.data.companyid == request.auth.token.companyid;
    }

    // Customers (existing)
    match /customers/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 4: Update Main App Configuration

**In your main.dart:**

```dart
import 'package:provider/provider.dart';
import 'package:kologsoft/providers/SMSProvider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Your existing providers...
        ChangeNotifierProvider(create: (_) => SMSProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
```

### Step 5: Navigation Integration

**Add to your navigation/sidebar:**

```dart
// In your sidebar.dart or navigation file
ListTile(
  leading: const Icon(Icons.sms),
  title: const Text('SMS Management'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SMSManagement(
          companyId: currentUser.companyId,
          branchId: currentUser.branchId,
          staffName: currentUser.name,
        ),
      ),
    );
  },
)
```

## Usage Guide

### Sending Single SMS

```dart
final provider = Provider.of<SMSProvider>(context, listen: false);

await provider.sendSingleSMS(
  companyId: 'KS005',
  branchId: 'ks005garu',
  staff: 'Abiiro John',
  phoneNumber: '0558807644',
  message: 'Hello Matthews! Special offer just for you.',
);
```

### Sending Bulk SMS with Filters

```dart
// Get all customers for the company
final customers = await _firestore
    .collection('customers')
    .where('companyid', isEqualTo: 'KS005')
    .get();

final phoneNumbers = customers.docs
    .map((doc) => doc['contact'].toString())
    .toList();

await provider.sendBulkSMS(
  companyId: 'KS005',
  branchId: 'ks005garu',
  staff: 'Abiiro John',
  phoneNumbers: phoneNumbers,
  message: 'New stock arrived! Visit us today.',
  filterType: 'all',
);
```

### Birthday Feature

The birthday feature requires adding `dateofbirth` field to your customers collection:

```dart
// Update customer with birthday
await _firestore.collection('customers').doc(customerId).update({
  'dateofbirth': Timestamp.fromDate(DateTime(1990, 5, 15)),
});
```

## SMS Service Provider Integration

The current implementation saves SMS records to Firestore but doesn't actually send them. To integrate with an actual SMS provider, update the `sendSingleSMS`, `sendBulkSMS`, `sendBirthdayGreeting`, and `sendSeasonalGreeting` methods.

### Recommended SMS Providers

1. **Twilio** - Most popular, great documentation
   ```dart
   // Example integration point
   // In sendSingleSMS() method:
   final response = await http.post(
     Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json'),
     headers: {
       'Authorization': 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
     },
     body: {
       'From': twilioPhoneNumber,
       'To': phoneNumber,
       'Body': message,
     },
   );
   ```

2. **AWS SNS** - Good for scale
3. **Firebase Cloud Functions** - Native Firebase integration
4. **Local SMS Gateway** - If you have on-premise solution

### Implementation Steps for SMS Provider

1. Add API credentials to Firebase Remote Config or Environment variables
2. Create a Firebase Cloud Function to handle SMS sending
3. Call the Cloud Function from the Provider
4. Update message status to 'sent' or 'failed'

## Features Explained

### 1. Send SMS Tab
- **Single SMS**: Direct customer targeting
- **Bulk SMS**: Multiple recipient options
  - All customers
  - Branch-specific
  - Customer type filtering (Cash/Credit/Wholesale)
- Character counter (SMS length: 160 chars = 1 SMS, 161-480 = 2-3 SMS)

### 2. Birthdays Tab
- Automatic detection of upcoming birthdays (7-day window)
- Pre-configured templates
- Manual send option
- Auto-send toggle (requires Cloud Functions setup)
- Shows customer name and birthdate

### 3. Seasonal Greetings Tab
- Pre-configured occasions:
  - Christmas
  - New Year
  - Easter
  - Thanksgiving
  - Ramadan
  - Eid
  - Custom messages
- Send to all company customers
- Recipient count preview

### 4. History Tab
- Filter by SMS type (All, Single, Bulk, Birthday, Seasonal)
- Message preview
- Recipient count
- Status tracking
- Timestamp for each campaign

## Best Practices

### Do's ✅
- Always use templates for consistent messaging
- Verify phone numbers before bulk sends
- Set up birthday dates during customer registration
- Monitor SMS statistics regularly
- Use company-wide branding in messages
- Schedule bulk messages during business hours
- Test with a single SMS first before bulk sends

### Don'ts ❌
- Don't send more than 20 SMS per second (SMS rate limiting)
- Don't send marketing SMS at night (respect customer time zones)
- Don't skip customer consent for promotional SMS
- Don't use all-caps messages (appears aggressive)
- Don't forget to update customer contact info

## Testing

### Test Data Setup

```dart
// Add test customer with birthday
await _firestore.collection('customers').add({
  'name': 'Test Customer',
  'contact': '0558807644',
  'companyid': 'KS005',
  'branchid': 'ks005garu',
  'dateofbirth': Timestamp.fromDate(DateTime(1990, DateTime.now().month, DateTime.now().day)),
  'customertype': 'cash',
  'creditBalance': 0,
  'creditlimit': 5000,
});
```

### Test Cases

1. **Single SMS** - Send to one customer
2. **Bulk SMS** - Send to all customers of a branch
3. **Birthday Detection** - Verify customers with upcoming birthdays appear
4. **History Logging** - Confirm all messages appear in history
5. **Statistics** - Check SMS statistics calculate correctly

## Troubleshooting

### Issue: Birthday not appearing
- **Solution**: Ensure `dateofbirth` field exists in customer document
- **Check**: Verify date is in correct format (Firestore Timestamp)

### Issue: SMS status stuck as "pending"
- **Solution**: Verify SMS provider integration is complete
- **Check**: Look for error logs in Cloud Functions

### Issue: Bulk SMS button disabled
- **Solution**: Ensure customers exist in Firestore
- **Check**: Verify query filters are correctly applied

### Issue: Character limit not showing correct SMS count
- **Solution**: Clear browser cache or restart app
- **Check**: Verify `intl` package is properly imported

## Performance Optimization

For large customer bases (1000+):

1. **Pagination**: Implement pagination in history view
   ```dart
   .limit(50) // Load 50 at a time
   ```

2. **Caching**: Cache frequently used data
3. **Indexing**: Create proper Firestore indexes (see Step 2)
4. **Batch Operations**: Group SMS into batches for sending

## Security Considerations

1. **Phone Number Privacy**: Hash phone numbers in logs if needed
2. **Message Logging**: Comply with GDPR/CCPA regulations
3. **Access Control**: Limit SMS sending to authorized staff
4. **Rate Limiting**: Implement quotas per user/day
5. **Audit Trail**: Log who sent what message and when

## Future Enhancements

- SMS scheduling (send at specific time)
- Delivery reports (integration with SMS provider)
- SMS templates builder with preview
- WhatsApp integration
- Backup SMS provider failover
- SMS cost analytics
- A/B testing for messages
- Two-way SMS (customer replies)
- SMS survey integration

## Support & Maintenance

- Monitor Firestore usage for costs
- Review SMS statistics monthly
- Archive old SMS logs (90+ days)
- Update templates seasonally
- Test SMS provider API changes quarterly

---

**Last Updated**: June 2026
**Version**: 1.0.0
