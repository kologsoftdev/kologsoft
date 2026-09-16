import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/sms_template.dart';
import '../services/sms_template_service.dart';
import 'sms_template_manager.dart';

class SMSManagement extends StatefulWidget {
  final String companyId;
  final String branchId;
  final String staffName;

  const SMSManagement({
    super.key,
    required this.companyId,
    required this.branchId,
    required this.staffName,
  });

  @override
  State<SMSManagement> createState() => _SMSManagementState();
}

class _SMSManagementState extends State<SMSManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'SMS Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicator: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.blueAccent,
                width: 3,
              ),
            ),
          ),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(
              icon: Icon(Icons.send_rounded, color: Colors.blueAccent),
              text: 'Send SMS',
            ),
            Tab(
              icon: Icon(Icons.cake_rounded, color: Colors.pinkAccent),
              text: 'Birthdays',
            ),
            Tab(
              icon: Icon(Icons.celebration_rounded, color: Colors.orangeAccent),
              text: 'Seasonal',
            ),
            Tab(
              icon: Icon(Icons.history_rounded, color: Colors.tealAccent),
              text: 'History',
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manage templates',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SMSTemplateManagerScreen(companyId: widget.companyId),
              ));
            },
            icon: const Icon(Icons.edit_note_outlined),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SendSMSPage(
            companyId: widget.companyId,
            branchId: widget.branchId,
            staffName: widget.staffName,
          ),
          BirthdayGreetingsPage(
            companyId: widget.companyId,
            branchId: widget.branchId,
            staffName: widget.staffName,
          ),
          SeasonalGreetingsPage(
            companyId: widget.companyId,
            branchId: widget.branchId,
            staffName: widget.staffName,
          ),
          SMSHistoryPage(
            companyId: widget.companyId,
            branchId: widget.branchId,
          ),
        ],
      ),
    );
  }
}

// Send SMS Page - For Single or Bulk SMS
class SendSMSPage extends StatefulWidget {
  final String companyId;
  final String branchId;
  final String staffName;

  const SendSMSPage({
    super.key,
    required this.companyId,
    required this.branchId,
    required this.staffName,
  });

  @override
  State<SendSMSPage> createState() => _SendSMSPageState();
}

class _SendSMSPageState extends State<SendSMSPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _senderIdController = TextEditingController();

  String _sendType = 'single';
  String _bulkFilterType = 'customerType';
  String? _selectedCustomerType;
  String? _selectedCropMajor;
  String? _selectedLanguage;
  String? _selectedCommunity;
  String? _selectedGender;
  String? _selectedDistrict;
  String? _selectedEducation;
  List<String> _selectedPhoneNumbers = [];
  int _messageCharCount = 0;
  bool _isSending = false;
  List<dynamic> _filteredCustomers = [];
  List<String> _availableCustomerTypes = [];
  List<String> _availableCropsMajor = [];
  List<String> _availableLanguages = [];
  List<String> _availableCommunities = [];
  List<String> _availableGenders = ['Male', 'Female', 'Other'];
  List<String> _availableDistricts = [];
  List<String> _availableEducationLevels = [];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        _messageCharCount = _messageController.text.length;
      });
    });
    _senderIdController.text = '';
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final customerSnapshot = await _firestore
          .collection('customers')
          .where('companyid', isEqualTo: widget.companyId)
          .get();

      final customerTypes = <String>{};
      final cropsMajor = <String>{};
      final languages = <String>{};
      final communities = <String>{};
      final educationLevels = <String>{};

      for (var doc in customerSnapshot.docs) {
        final data = doc.data();
        if (data['customertype'] != null) {
          customerTypes.add(data['customertype'].toString());
        }
        if (data['majorcrop'] != null) {
          cropsMajor.add(data['majorcrop'].toString());
        }
        if (data['languagespokens'] != null && data['languagespokens'] is List) {
          final langList = List<dynamic>.from(data['languagespokens']);
          for (var lang in langList) {
            if (lang != null) {
              languages.add(lang.toString());
            }
          }
        }
        if (data['community'] != null) {
          communities.add(data['community'].toString());
        }
        if (data['educationlevel'] != null) {
          educationLevels.add(data['educationlevel'].toString());
        }
      }

      setState(() {
        _availableCustomerTypes = customerTypes.toList()..sort();
        _availableCropsMajor = cropsMajor.toList()..sort();
        _availableLanguages = languages.toList()..sort();
        _availableCommunities = communities.toList()..sort();
        _availableEducationLevels = educationLevels.toList()..sort();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading filters: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    _senderIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchFilteredCustomers() async {
    try {
      Query query = _firestore
          .collection('customers')
          .where('companyid', isEqualTo: widget.companyId);

      switch (_bulkFilterType) {
        case 'branch':
          query = query.where('branchid', isEqualTo: widget.branchId);
          break;
        case 'customerType':
          if (_selectedCustomerType != null) {
            query = query.where('customertype', isEqualTo: _selectedCustomerType);
          }
          break;
        case 'cropMajor':
          if (_selectedCropMajor != null) {
            query = query.where('majorcrop', isEqualTo: _selectedCropMajor);
          }
          break;
        case 'language':
          if (_selectedLanguage != null) {
            query = query.where('languagespokens', arrayContains: _selectedLanguage);
          }
          break;
        case 'community':
          if (_selectedCommunity != null) {
            query = query.where('community', isEqualTo: _selectedCommunity);
          }
          break;
        case 'gender':
          if (_selectedGender != null) {
            query = query.where('gender', isEqualTo: _selectedGender);
          }
          break;
        case 'educationLevel':
          if (_selectedEducation != null) {
            query = query.where('educationlevel', isEqualTo: _selectedEducation);
          }
          break;
      }

      final snapshot = await query.get();
      setState(() {
        _filteredCustomers = snapshot.docs;
        if (_sendType == 'bulk') {
          _selectedPhoneNumbers = snapshot.docs
              .map((doc) => doc['contact']?.toString() ?? doc['phone']?.toString() ?? '')
              .where((phone) => phone.isNotEmpty)
              .toList();
        }
        print(_selectedPhoneNumbers);
      });

      if (mounted && _selectedPhoneNumbers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No farmers found with this filter')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching farmers: $e')),
        );
      }
    }
  }

  Future<void> _sendSMS() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final message = _messageController.text;
      final senderId =  _senderIdController.text;

      if (_sendType == 'single') {
        if (_phoneController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter phone number')),
          );
          setState(() => _isSending = false);
          return;
        }

        final smsRecord = {
          'companyid': widget.companyId,
          'branchid': widget.branchId,
          'staff': widget.staffName,
          'message': message,
          'senderid': senderId,
          'recipient': _phoneController.text,
          'type': 'single',
          'bulkFilterType': null,
          'status': 'pending',
          'successMessage': '',
          'failureReason': '',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        await _firestore.collection('sms_logs').add(smsRecord);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS saved and queued for sending'),
              backgroundColor: Colors.blue,
            ),
          );

          _messageController.clear();
          _phoneController.clear();
        }
      } else {
        if (_bulkFilterType == 'customerType' && _selectedCustomerType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a customer type')),
          );
          setState(() => _isSending = false);
          return;
        }
        if (_bulkFilterType == 'cropMajor' && _selectedCropMajor == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a crop')),
          );
          setState(() => _isSending = false);
          return;
        }
        if (_bulkFilterType == 'language' && _selectedLanguage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a language')),
          );
          setState(() => _isSending = false);
          return;
        }
        if (_bulkFilterType == 'community' && _selectedCommunity == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a community')),
          );
          setState(() => _isSending = false);
          return;
        }
        if (_bulkFilterType == 'gender' && _selectedGender == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a gender')),
          );
          setState(() => _isSending = false);
          return;
        }
        if (_bulkFilterType == 'educationLevel' && _selectedEducation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select an education level')),
          );
          setState(() => _isSending = false);
          return;
        }

        String filterValue = '';
        switch (_bulkFilterType) {
          case 'customerType':
            filterValue = _selectedCustomerType ?? '';
            break;
          case 'cropMajor':
            filterValue = _selectedCropMajor ?? '';
            break;
          case 'language':
            filterValue = _selectedLanguage ?? '';
            break;
          case 'branch':
            filterValue = widget.branchId;
            break;
          case 'community':
            filterValue = _selectedCommunity ?? '';
            break;
          case 'gender':
            filterValue = _selectedGender ?? '';
            break;
          case 'educationLevel':
            filterValue = _selectedEducation ?? '';
            break;
        }

        final bulkSMSRecord = {
          'companyid': widget.companyId,
          'branchid': widget.branchId,
          'staff': widget.staffName,
          'message': message,
          'senderid': senderId,
          'type': 'bulk',
          'bulkFilterType': _bulkFilterType,
          'bulkFilterValue': filterValue,
          'status': 'pending',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        await _firestore.collection('sms_logs').add(bulkSMSRecord);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bulk SMS queued. Processing and sending now...'),
              backgroundColor: Colors.blue,
            ),
          );

          _messageController.clear();
          _selectedPhoneNumbers.clear();
          _selectedCustomerType = null;
          _selectedCropMajor = null;
          _selectedLanguage = null;
          _selectedCommunity = null;
          _selectedGender = null;
          _selectedEducation = null;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Modern Send Type Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A2744), Color(0xFF223456)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.blueAccent, Colors.purpleAccent],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'SMS Campaign',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _sendType = 'single'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _sendType == 'single'
                                      ? Colors.blueAccent.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: _sendType == 'single'
                                      ? Border.all(
                                    color: Colors.blueAccent,
                                    width: 1,
                                  )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: _sendType == 'single'
                                          ? Colors.blueAccent
                                          : Colors.white54,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Single SMS',
                                      style: TextStyle(
                                        color: _sendType == 'single'
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: _sendType == 'single'
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _sendType = 'bulk'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _sendType == 'bulk'
                                      ? Colors.blueAccent.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: _sendType == 'bulk'
                                      ? Border.all(
                                    color: Colors.blueAccent,
                                    width: 1,
                                  )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.groups_rounded,
                                      color: _sendType == 'bulk'
                                          ? Colors.blueAccent
                                          : Colors.white54,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Bulk SMS',
                                      style: TextStyle(
                                        color: _sendType == 'bulk'
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: _sendType == 'bulk'
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_sendType == 'bulk')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_rounded,
                              color: Colors.greenAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Recipients selected: ${_selectedPhoneNumbers.length}",
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Single SMS Input
              if (_sendType == 'single')
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2744),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter phone number',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(
                            Icons.phone_rounded,
                            color: Colors.white38,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),

              // Bulk SMS Filters
              if (_sendType == 'bulk')
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2744),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Recipients',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _bulkFilterType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A2744),
                            style: const TextStyle(color: Colors.white),
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Colors.white54,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('All Customers'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'branch',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('Current Branch Only'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'customerType',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('By Customer Type'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'cropMajor',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('By Major Crop'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'language',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('By Language'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'community',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('By Community'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'gender',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('By Gender'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'educationLevel',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('By Education Level'),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _bulkFilterType = value!;
                                _selectedCustomerType = null;
                                _selectedCropMajor = null;
                                _selectedLanguage = null;
                                _selectedCommunity = null;
                                _selectedGender = null;
                                _selectedEducation = null;
                                _selectedPhoneNumbers.clear();
                              });
                            },
                          ),
                        ),
                      ),
                      // Filter dropdowns
                      if (_bulkFilterType == 'customerType')
                        _buildFilterDropdown(
                          value: _selectedCustomerType,
                          items: _availableCustomerTypes,
                          hint: 'Select Customer Type',
                          onChanged: (v) => setState(() => _selectedCustomerType = v),
                        ),
                      if (_bulkFilterType == 'cropMajor')
                        _buildFilterDropdown(
                          value: _selectedCropMajor,
                          items: _availableCropsMajor,
                          hint: 'Select Major Crop',
                          onChanged: (v) => setState(() => _selectedCropMajor = v),
                        ),
                      if (_bulkFilterType == 'language')
                        _buildFilterDropdown(
                          value: _selectedLanguage,
                          items: _availableLanguages,
                          hint: 'Select Language',
                          onChanged: (v) => setState(() => _selectedLanguage = v),
                        ),
                      if (_bulkFilterType == 'community')
                        _buildFilterDropdown(
                          value: _selectedCommunity,
                          items: _availableCommunities,
                          hint: 'Select Community',
                          onChanged: (v) => setState(() => _selectedCommunity = v),
                        ),
                      if (_bulkFilterType == 'gender')
                        _buildFilterDropdown(
                          value: _selectedGender,
                          items: _availableGenders,
                          hint: 'Select Gender',
                          onChanged: (v) => setState(() => _selectedGender = v),
                        ),
                      if (_bulkFilterType == 'educationLevel')
                        _buildFilterDropdown(
                          value: _selectedEducation,
                          items: _availableEducationLevels,
                          hint: 'Select Education Level',
                          onChanged: (v) => setState(() => _selectedEducation = v),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _fetchFilteredCustomers,
                          icon: const Icon(Icons.filter_list_rounded, size: 18),
                          label: const Text('Apply Filter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withOpacity(0.15),
                            foregroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.blueAccent.withOpacity(0.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Message Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2744),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.message_rounded,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Message',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _messageCharCount > 160
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _messageCharCount > 160
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            "$_messageCharCount chars",
                            style: TextStyle(
                              color: _messageCharCount > 160
                                  ? Colors.orange
                                  : Colors.greenAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 6,
                      maxLength: 480,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter your message (max 160 characters per SMS)',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: const TextStyle(color: Colors.white38),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Send Button
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendSMS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Send SMS',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  hint,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              isExpanded: true,
              dropdownColor: const Color(0xFF1A2744),
              style: const TextStyle(color: Colors.white),
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.white54,
              ),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(item),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// Birthday Greetings Page
class BirthdayGreetingsPage extends StatefulWidget {
  final String companyId;
  final String branchId;
  final String staffName;

  const BirthdayGreetingsPage({
    super.key,
    required this.companyId,
    required this.branchId,
    required this.staffName,
  });

  @override
  State<BirthdayGreetingsPage> createState() => _BirthdayGreetingsPageState();
}

class _BirthdayGreetingsPageState extends State<BirthdayGreetingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _templateController = TextEditingController();

  String _selectedTemplate = 'default';
  bool _autoSendEnabled = false;
  List<Map<String, dynamic>> _upcomingBirthdays = [];
  bool _isLoading = false;

  final Map<String, String> _templates = {};
  List<SmsTemplate> _templatesList = [];
  final SmsTemplateService _templateService = SmsTemplateService();

  @override
  void initState() {
    super.initState();
    _fetchUpcomingBirthdays();
    _loadBirthdayTemplates();
  }

  Future<void> _loadBirthdayTemplates() async {
    try {
      final list = await _templateService.getTemplatesByOccasion(widget.companyId, 'birthday');
      setState(() {
        _templatesList = list;
        _templates.clear();
        for (var t in list) {
          _templates[t.id] = t.message;
        }
        if (_templatesList.isNotEmpty) {
          _selectedTemplate = _templatesList.first.id;
        }
      });
    } catch (e) {
      // ignore errors silently for now
    }
  }

  Future<void> _fetchUpcomingBirthdays() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now();
      final nextWeek = today.add(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('customers')
          .where('companyid', isEqualTo: widget.companyId)
          .where('dateofbirth', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('dateofbirth', isLessThanOrEqualTo: Timestamp.fromDate(nextWeek))
          .get();

      setState(() {
        _upcomingBirthdays = snapshot.docs
            .map((doc) => {
          ...doc.data() as Map<String, dynamic>,
          'docId': doc.id,
        })
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching birthdays: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendBirthdayGreeting(Map<String, dynamic> customer) async {
    try {
      final message = _templates[_selectedTemplate] ?? 'Happy Birthday!';
      final customizedMessage = message.replaceAll('{{name}}', customer['name'] ?? 'Friend');

      await _firestore.collection('sms_logs').add({
        'companyid': widget.companyId,
        'branchid': widget.branchId,
        'staff': widget.staffName,
        'customerId': customer['id'],
        'customerName': customer['name'],
        'message': customizedMessage,
        'recipients': [customer['contact']],
        'type': 'birthday',
        'status': 'sent',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Birthday greeting sent to ${customer['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template Selection
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2744), Color(0xFF223456)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.pinkAccent, Colors.purpleAccent],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cake_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Birthday Greeting Template',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTemplate,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A2744),
                      style: const TextStyle(color: Colors.white),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.white54,
                      ),
                      items: _templatesList
                          .map(
                            (t) => DropdownMenuItem(
                          value: t.id,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(t.name),
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedTemplate = value!);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Text(
                    _templates[_selectedTemplate] ?? '',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Auto-Send Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2744),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto Birthday Sending',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Send greetings automatically on birthdays',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoSendEnabled,
                  onChanged: (value) {
                    setState(() => _autoSendEnabled = value);
                  },
                  activeColor: Colors.blueAccent,
                  activeTrackColor: Colors.blueAccent.withOpacity(0.3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Upcoming Birthdays Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Birthdays (7 Days)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              if (_upcomingBirthdays.isNotEmpty)
                TextButton.icon(
                  onPressed: _fetchUpcomingBirthdays,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: Colors.blueAccent,
                    size: 18,
                  ),
                  label: Text(
                    'Refresh',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_upcomingBirthdays.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No upcoming birthdays in the next 7 days',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingBirthdays.length,
              itemBuilder: (context, index) {
                final customer = _upcomingBirthdays[index];
                final birthDate = customer['dateofbirth'] is Timestamp
                    ? (customer['dateofbirth'] as Timestamp).toDate()
                    : DateTime.parse(customer['dateofbirth'].toString());

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2744),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.pinkAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer['name'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd').format(birthDate),
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _sendBirthdayGreeting(customer),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Send'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent.withOpacity(0.15),
                          foregroundColor: Colors.pinkAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Colors.pinkAccent.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }
}

// Seasonal Greetings Page
class SeasonalGreetingsPage extends StatefulWidget {
  final String companyId;
  final String branchId;
  final String staffName;

  const SeasonalGreetingsPage({
    super.key,
    required this.companyId,
    required this.branchId,
    required this.staffName,
  });

  @override
  State<SeasonalGreetingsPage> createState() => _SeasonalGreetingsPageState();
}

class _SeasonalGreetingsPageState extends State<SeasonalGreetingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();

  String _selectedSeason = 'christmas';
  bool _isSending = false;
  int _recipientCount = 0;

  final Map<String, String> _seasonalMessages = {
    'christmas': 'Merry Christmas! Thank you for your continued support. Wishing you joy and prosperity this festive season.',
    'newyear': 'Happy New Year! Here\'s to a prosperous year ahead. Thank you for being part of our journey.',
    'easter': 'Happy Easter! We appreciate your business. Wishing you and your family a blessed Easter celebration.',
    'thanksgiving': 'Happy Thanksgiving! We are grateful for your loyalty and support.',
    'ramadan': 'Ramadan Kareem! Wishing you and your family blessings during this holy month.',
    'eid': 'Eid Mubarak! Thank you for your continued patronage.',
    'thanksgiving_day': 'Happy Thanksgiving Day! We appreciate your business and support.',
    'custom': 'Enter custom message...',
  };

  List<SmsTemplate> _seasonalTemplates = [];
  final SmsTemplateService _templateService = SmsTemplateService();

  @override
  void initState() {
    super.initState();
    _messageController.text = _seasonalMessages['christmas']!;
    _loadSeasonalTemplates();
  }

  Future<void> _loadSeasonalTemplates() async {
    try {
      final list = await _templateService.getTemplatesByOccasion(widget.companyId, 'seasonal');
      setState(() {
        _seasonalTemplates = list;
        if (_seasonalTemplates.isNotEmpty) {
          // if any template has a tag matching the currently selected season, use it
          final match = _seasonalTemplates.firstWhere((t) => t.tag == _selectedSeason, orElse: () => _seasonalTemplates.first);
          _messageController.text = match.message;
        }
      });
    } catch (e) {
      // ignore for now
    }
  }

  Future<void> _fetchRecipientCount() async {
    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('companyid', isEqualTo: widget.companyId)
          .count()
          .get();

      setState(() => _recipientCount = snapshot.count!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching recipients: $e')),
        );
      }
    }
  }

  Future<void> _sendSeasonalGreeting() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('companyid', isEqualTo: widget.companyId)
          .get();

      final recipients = snapshot.docs
          .map((doc) => doc['contact'].toString())
          .toList();

      await _firestore.collection('sms_logs').add({
        'companyid': widget.companyId,
        'branchid': widget.branchId,
        'staff': widget.staffName,
        'message': _messageController.text,
        'recipientCount': recipients.length,
        'recipients': recipients,
        'type': 'seasonal',
        'season': _selectedSeason,
        'status': 'scheduled',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seasonal greeting scheduled for ${recipients.length} customers'),
            backgroundColor: Colors.green,
          ),
        );
        _messageController.text = _seasonalMessages[_selectedSeason] ?? '';
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season Selection
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2744), Color(0xFF223456)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orangeAccent, Colors.redAccent],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Seasonal / Occasion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSeason,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A2744),
                      style: const TextStyle(color: Colors.white),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.white54,
                      ),
                      items: _seasonalMessages.keys
                          .map((season) => DropdownMenuItem(
                        value: season,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            season.replaceAll('_', ' ').toUpperCase(),
                          ),
                        ),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSeason = value!;
                          if (_selectedSeason != 'custom') {
                            final match = _seasonalTemplates.firstWhere(
                                (t) => t.tag == _selectedSeason,
                                orElse: () => SmsTemplate(
                                      id: '',
                                      companyId: widget.companyId,
                                      occasion: 'seasonal',
                                      name: '',
                                      message: '',
                                      tag: null,
                                      createdAt: Timestamp.now(),
                                      updatedAt: Timestamp.now(),
                                    ));
                            if (match.id.isNotEmpty) {
                              _messageController.text = match.message;
                            } else if (_seasonalMessages.containsKey(_selectedSeason)) {
                              _messageController.text = _seasonalMessages[_selectedSeason]!;
                            }
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Message Input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2744),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter your seasonal message',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Character count: ${_messageController.text.length}',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recipient Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2744),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people_rounded,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$_recipientCount customers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _fetchRecipientCount,
                  child: Text(
                    'Update Count',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Send Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendSeasonalGreeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSending
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Send to All Customers',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

// SMS History Page
class SMSHistoryPage extends StatefulWidget {
  final String companyId;
  final String branchId;

  const SMSHistoryPage({
    super.key,
    required this.companyId,
    required this.branchId,
  });

  @override
  State<SMSHistoryPage> createState() => _SMSHistoryPageState();
}

class _SMSHistoryPageState extends State<SMSHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2744),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterType,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A2744),
                style: const TextStyle(color: Colors.white),
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.white54,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All SMS')),
                  DropdownMenuItem(value: 'single', child: Text('Single SMS')),
                  DropdownMenuItem(value: 'bulk', child: Text('Bulk SMS')),
                  DropdownMenuItem(value: 'birthday', child: Text('Birthday Greetings')),
                  DropdownMenuItem(value: 'seasonal', child: Text('Seasonal Greetings')),
                ],
                onChanged: (value) {
                  setState(() => _filterType = value!);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print(snapshot.error);
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data?.docs.isEmpty ?? true) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No SMS records found',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2744),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getTypeColor(data['type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getTypeIcon(data['type']),
                          color: _getTypeColor(data['type']),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        data['type']?.toString().toUpperCase() ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('MMM dd, yyyy - hh:mm a').format(
                          (data['createdAt'] as Timestamp).toDate(),
                        ),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: data['status'] == 'sent'
                              ? Colors.green.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: data['status'] == 'sent'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          data['status'] ?? 'Unknown',
                          style: TextStyle(
                            color: data['status'] == 'sent'
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Message',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  data['message'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_rounded,
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Recipients: ${data['recipientCount'] ?? data['recipients']?.length ?? 'N/A'}',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (data['staff'] != null)
                                    Text(
                                      'By: ${data['staff']}',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query query = _firestore
        .collection('sms_logs')
        .where('companyid', isEqualTo: widget.companyId)
        .orderBy('createdAt', descending: true)
        .limit(100);

    if (_filterType != 'all') {
      query = query.where('type', isEqualTo: _filterType);
    }

    return query.snapshots();
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'single':
        return Icons.person_rounded;
      case 'bulk':
        return Icons.groups_rounded;
      case 'birthday':
        return Icons.cake_rounded;
      case 'seasonal':
        return Icons.celebration_rounded;
      default:
        return Icons.sms_rounded;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'single':
        return Colors.blueAccent;
      case 'bulk':
        return Colors.greenAccent;
      case 'birthday':
        return Colors.pinkAccent;
      case 'seasonal':
        return Colors.orangeAccent;
      default:
        return Colors.white54;
    }
  }
}