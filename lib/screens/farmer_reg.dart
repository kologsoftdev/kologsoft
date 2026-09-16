import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/languageModel.dart';
import 'package:kologsoft/providers/StockProvider.dart';
import 'package:kologsoft/screens/viewfarmers.dart';
import 'package:multi_select_flutter/dialog/mult_select_dialog.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:provider/provider.dart';
import '../models/cropModel.dart';
import '../models/farmerModel.dart';

class FarmerRegistration extends StatefulWidget {
  final String? docId;
  final FarmerRegModel? data;
  const FarmerRegistration({super.key,this.docId, this.data});

  @override
  State<FarmerRegistration> createState() => _FarmerRegistrationState();
}

class _FarmerRegistrationState extends State<FarmerRegistration> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _creditlimitController = TextEditingController();
  final TextEditingController _popularNameController = TextEditingController();
  final TextEditingController _householdController = TextEditingController();
  final TextEditingController _homeaddressController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController ghanaCardController = TextEditingController();
  final TextEditingController _parttimestaffController = TextEditingController();
  final TextEditingController _fulltimestaffController = TextEditingController();
  final TextEditingController _businnessnameController = TextEditingController();
  final TextEditingController _businessaddressController = TextEditingController();
  final TextEditingController homelongititude = TextEditingController();
  final TextEditingController homelatitude = TextEditingController();
  final TextEditingController buslongititude = TextEditingController();
  final TextEditingController buslatitude = TextEditingController();
  final TextEditingController _homegpsController = TextEditingController();
  final TextEditingController _businessgpsController = TextEditingController();

  String? _selectedEducation;
  String? _selectedMajorcrop;
  String? _selectedRegionName;
  String? _selectedDistrictName;
  Map<String,dynamic>? _selectedCustomerType;
  String? _businessRegistered;
  String? _selectedSex;
  bool _loading=false;
  late List<String> paymentduration = ['Short term', 'Long term'];
  late List<String> Sex = ['Male', 'Female'];
  late List<String> registered = ['Yes', 'No'];
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _constituencies = [];
  List<Map<String, dynamic>> _electoralAreas = [];
  List<Map<String, dynamic>> _electoralAreasfromfile = [];

  String? _selectedRegionCode;
  String? _selectedConstituencyCode;
  String? _selectedElectoralArea;
  bool _loadingRegions = true;
  bool _loadingConstituencies = true;
  bool _loadingElectoralAreas = true;
  List<dynamic> spokenlanguages = [];
  List<dynamic> minorcroplisit = [];
  List<LanguageModel> _selectedLanguages = [];
  List<CropModel> _selectedMinorcrop = [];

  String? _selectedCustomaType;
  String? _selectedpaymentduration;

  late List<String> _customaTypes = ['Cash', 'Credit'];

  bool get isCreditCustomer => _selectedCustomaType == 'Credit';

  late List<Map<String, dynamic>> _customerTypes = [
    {'id': 'RB', 'name': 'Retail farmer'},
    {'id': 'CF', 'name': 'Commercial farmer'},
    {'id': 'SF', 'name': 'Smallholder farmer'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRegionData();
  }

  Future _loadRegionData() async {
    final stockprovider= Provider.of<StockProvider>(context, listen: false);

    try {
      final regionStr = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/json/region.json');
      final constStr = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/json/constituency.json');
      final eaStr = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/json/electoralarea.json');
      setState(() {
        _regions = List<Map<String, dynamic>>.from(jsonDecode(regionStr));
        _constituencies = List<Map<String, dynamic>>.from(jsonDecode(constStr));
        _electoralAreasfromfile = List<Map<String, dynamic>>.from(jsonDecode(eaStr));
        _electoralAreas = [
          ..._electoralAreasfromfile,
          ...stockprovider.communities,
        ];
        _loadingRegions = false;
        _loadingConstituencies = false;
        _loadingElectoralAreas = false;
      });
      if (widget.data != null) {
        final customadata = widget.data!;

        final match = _regions.where((r) => r['regionname'] == customadata.region,).toList();
        final matchdistrict = _constituencies.where((d) => d['constname'] == customadata.district,).toList();
        final matchcommunity = _electoralAreas.where((c) => c['constname'] == customadata.community,).toList();

        if (match.isNotEmpty) {
          setState(() {
            _selectedRegionCode = match.first['regioncode'];
            _selectedRegionName = match.first['regionname'];
            _selectedDistrictName  = matchdistrict.first['constname'];
            _selectedConstituencyCode = matchdistrict.first['constcode'];
            _selectedDistrictName = matchcommunity.first['electoralarea'];
          });
        }
      }
    } catch (e) {
      setState(() {
        _loadingRegions = false;
        _loadingConstituencies = false;
        _loadingElectoralAreas = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredConstituencies =>
      _selectedRegionCode == null
          ? []
          : _constituencies
          .where((c) => c['regioncode'] == _selectedRegionCode)
          .toList();

  List<Map<String, dynamic>> get _filteredElectoralAreas =>
      _selectedConstituencyCode == null
          ? []
          : _electoralAreas
          .where((ea) => ea['constcode'] == _selectedConstituencyCode)
          .toList();
  bool get isSmallholderFarmer => _selectedCustomerType?['name'] == 'Smallholder farmer';
  bool get isBusinessRegistered => _businessRegistered == 'Yes';
  @override
  void initState() {
    super.initState();

    Future.microtask(()async{
      final stockprovider= Provider.of<StockProvider>(context, listen: false);
      await stockprovider.getdata();
        stockprovider.fetchBranches();
       stockprovider.fetchLanguages();
      stockprovider.fetchCrops();
      stockprovider.fetcheducationlevels();
      stockprovider.fetchCommunities();

      if(widget.data != null){
        final customadata = widget.data!;
        final branchId = widget.data!.branchid;
        if (branchId != null && branchId.isNotEmpty) {
          stockprovider.selectBranch(branchId);
        }
        _selectedMinorcrop = stockprovider.crops.where((crop) => customadata.minorcrop.contains(crop.name)).toList();
        _selectedLanguages = stockprovider.languages.where((lang) => customadata.languagespokens.contains(lang.name)).toList();

      }


    });

    if (widget.data != null) {

      final customadata = widget.data!;
      _nameController.text = customadata.name;
      _contactController.text = customadata.contact;
      _creditlimitController.text = customadata.creditlimit ?? '';
      _popularNameController.text = customadata.popularname;
      _householdController.text = customadata.household;
      _homeaddressController.text = customadata.homeaddress;
      dobController.text = customadata.dateofbirth;
      ghanaCardController.text = customadata.ghanacard;
      _parttimestaffController.text = customadata.parttimestaff!;
      _fulltimestaffController.text = customadata.fulltimestaff!;
      _businnessnameController.text = customadata.businessname!;
      _businessaddressController.text = customadata.businessaddress!;
      _homegpsController.text   = customadata.homegps!;
      _businessgpsController.text = customadata.businessgps!;
      _selectedEducation = customadata.educationlevel;
      _selectedMajorcrop = customadata.majorcrop;
      _selectedSex = customadata.gender;
      _selectedDistrictName = customadata.district;
      _selectedElectoralArea = customadata.community;
      _selectedEducation = customadata.educationlevel;
      spokenlanguages = customadata.languagespokens;
      final matchcustomer = _customerTypes.where((type) => type['name'] == customadata.customertype,);
      _selectedCustomerType = matchcustomer.isNotEmpty ? matchcustomer.first : null;
      _businessRegistered = customadata.registered ?? 'No';
      minorcroplisit = customadata.minorcrop;
      _selectedRegionName = customadata.region;
      final iscustomerType = customadata.iscashcustoma;
      if (_customaTypes.contains(iscustomerType)) {
        _selectedCustomaType = iscustomerType;
      }

      final paymentDuration = customadata.paymentduration;
      if (paymentduration.contains(paymentDuration)) {
        _selectedpaymentduration = paymentDuration;
      }

    }

  }
  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _creditlimitController.dispose();
   _popularNameController.dispose();
    _householdController.dispose();
    _homeaddressController.dispose();
    dobController.dispose();
    ghanaCardController.dispose();
    _parttimestaffController.dispose();
    _fulltimestaffController.dispose();
    _businnessnameController.dispose();
    _businessaddressController.dispose();
    _businessgpsController.dispose();
    _homegpsController.dispose();

    super.dispose();
  }

  Widget _twoCol(BuildContext context, Widget a, Widget b) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: a),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: b),
        ],
      );
    } else if (width < 1024) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.start,
        children: [
          SizedBox(width: 320, child: a),
          SizedBox(width: 320, child: b),
        ],
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white),
      prefixIcon: prefix != null ? Icon(prefix, color: Colors.white70) : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue),
      ),
      fillColor: const Color(0xFF22304A),
      filled: true,
    );
  }

  Widget _businessSection(BuildContext context) {
    return Column(
      children: [
        _twoCol(
          context,
          TextFormField(
            controller: _businnessnameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: "Business Name",
              prefix: Icons.home,
              hint: 'Enter Business Name',
            ),

            validator: (value) =>
            value == null || value.isEmpty ? 'Enter business name' : null,
          ),
          TextFormField(
            controller: _businessaddressController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: "Business Address",
              prefix: Icons.home,
              hint: 'Enter Business Address',
            ),
            validator: (value) =>
            value == null || value.isEmpty ? 'Enter Business Address' : null,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _businessgpsController,
          style: TextStyle(color: Colors.white70),
          decoration: InputDecoration(
            labelText: 'GhanaPost GPS Address',
            labelStyle: TextStyle(color: Colors.white70),
            prefixIcon: Icon(
              Icons.location_on,
              color: Colors.white70,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.white24,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            fillColor: const Color(0xFF22304A),
            filled: true,
            helperText: 'Format: AB-1234-5678',
            helperStyle: TextStyle(color: Colors.white70),
          ),
          inputFormatters: [
            TextInputFormatter.withFunction((
                oldValue,
                newValue,
                ) {
              String raw = newValue.text
                  .toUpperCase()
                  .replaceAll('-', '');
              String part1 = '';
              String part2 = '';
              String part3 = '';
              int i = 0;
              // Collect up to 2 letters
              while (i < raw.length && part1.length < 2) {
                if (RegExp(r'[A-Z]').hasMatch(raw[i])) {
                  part1 += raw[i];
                }
                i++;
              }
              // Collect up to 4 digits
              while (i < raw.length && part2.length < 4) {
                if (RegExp(r'\d').hasMatch(raw[i])) {
                  part2 += raw[i];
                }
                i++;
              }
              // Collect up to 4 more digits
              while (i < raw.length && part3.length < 4) {
                if (RegExp(r'\d').hasMatch(raw[i])) {
                  part3 += raw[i];
                }
                i++;
              }
              String text = part1;
              if (part1.length == 2) text += '-';
              text += part2;
              if (part2.length == 4) text += '-';
              text += part3;
              // Limit to max length (2+1+4+1+4 = 12)
              if (text.length > 12)
                text = text.substring(0, 12);
              // Set cursor position
              int offset = text.length;
              // If user is deleting a dash, move cursor back
              if (oldValue.text.endsWith('-') &&
                  oldValue.text.length > newValue.text.length) {
                offset--;
              }
              return TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(
                  offset: offset,
                ),
              );
            }),
          ],
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final ghanaPostReg = RegExp(
              r'^[A-Z]{2}-\d{4}-\d{4}$',
              caseSensitive: false,
            );
            if (!ghanaPostReg.hasMatch(v!.trim())) {
              return 'Enter a valid GhanaPost GPS address (e.g. AB-1234-5678)';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),
        _twoCol(
          context,
          TextFormField(
            controller: _fulltimestaffController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: "Full time staff",
              prefix: Icons.person_add_sharp,
              hint: 'Enter number of full time staff',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],

          ),
          TextFormField(
            controller: _parttimestaffController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: "Part time staff",
              prefix: Icons.group_add,
              hint: 'Enter number of part time staff',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
        builder: (BuildContext context, StockProvider value, Widget? child){
          return Scaffold(
            backgroundColor: const Color(0xFF101A23),
            appBar: AppBar(
              title: Text(widget.docId != null ? "Edit Farmer Registration" : "Farmer Registration"),
              backgroundColor: const Color(0xFF0D1A26),
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 700
                  ),
                  child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          Card(
                            color: const Color(0xFF182232),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0, top: 20, right: 16, bottom: 20),
                              child: Column(
                                children: [

                                  _twoCol(context,
                                    DropdownButtonFormField<Map<String, dynamic>>(
                                      value: _selectedCustomerType,
                                      dropdownColor: const Color(0xFF22304A),
                                      style: const TextStyle(color: Colors.white),
                                      hint: const Text(
                                        'Select farmer type',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Farmer Type',
                                        prefix: Icons.person_2_rounded,
                                      ),
                                      items: _customerTypes.map((type) {
                                        return DropdownMenuItem<Map<String, dynamic>>(
                                          value: type,
                                          child: Text(type['name']),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCustomerType = value;

                                        });
                                      },
                                      validator: (value) =>
                                      value == null ? 'Please select farmer type' : null,
                                    ),
                                    DropdownButtonFormField<String>(
                                      value: value.selectedBranch?.id,
                                      dropdownColor: const Color(0xFF22304A),
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Select Branch',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.white24),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.blue),
                                        ),
                                        fillColor: const Color(0xFF22304A),
                                        filled: true,
                                      ),
                                      items:(
                                          value.accesslevel == 'super admin'
                                              ? value.branches.where((b) => b.branchtype != "Warehouse")
                                              : value.branches.where((b) => b.id == value.branchid)
                                      ).map((branch) {
                                        return DropdownMenuItem<String>(
                                          value: branch.id,
                                          child: Text(branch.branchname),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          value.selectBranch(val);
                                        }
                                      },
                                      validator: (val) =>
                                      val == null ? 'Please select branch' : null,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _twoCol(context,
                                    TextFormField(
                                      controller: _nameController,
                                      style: TextStyle(color: Colors.white),
                                      decoration: _inputDecoration(
                                        label: 'Farmer Name',
                                        prefix: Icons.person,
                                        hint: 'Enter full name',
                                      ),
                                      validator: (value) => value == null || value.isEmpty
                                          ? 'Enter farmer name'
                                          : null,
                                    ),
                                    TextFormField(
                                      controller: _popularNameController,
                                      keyboardType: TextInputType.text,
                                      style: TextStyle(color: Colors.white),
                                      decoration: _inputDecoration(label: "Popular Name",
                                        prefix: Icons.person,
                                        hint: 'Enter popular name',),
                                      validator: (value) => value == null || value.isEmpty
                                          ? 'Enter popular name'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 14,),
                                  _twoCol(context,
                                    TextFormField(
                                    controller: _contactController,
                                    style: TextStyle(color: Colors.white70),
                                    decoration:_inputDecoration(label: "Phone Number",
                                      prefix: Icons.phone,
                                      hint: 'Enter contact number',
                                    ),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9+]'),
                                      ),
                                      LengthLimitingTextInputFormatter(13),
                                    ],
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Required';
                                      // Remove spaces and check format
                                      String cleaned = v.replaceAll(' ', '');
                                      // Ghana phone: 0XXXXXXXXX (10 digits) or +233XXXXXXXXX (13 chars)
                                      if (cleaned.startsWith('+233')) {
                                        if (cleaned.length != 13 ||
                                            !RegExp(r'^\+233\d{9}$').hasMatch(cleaned)) {
                                          return 'Invalid format. Use +233XXXXXXXXX';
                                        }
                                      } else if (cleaned.startsWith('0')) {
                                        if (cleaned.length != 10 ||
                                            !RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
                                          return 'Invalid format. Use 0XXXXXXXXX';
                                        }
                                      } else {
                                        return 'Phone must start with 0 or +233';
                                      }
                                      return null;
                                    },
                                  ),
                                    DropdownButtonFormField<String>(
                                      value: _selectedSex,
                                      dropdownColor: const Color(0xFF22304A),
                                      style: const TextStyle(color: Colors.white),
                                      hint: const Text(
                                        'Select gender',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Gender',
                                        prefix: Icons.person,

                                      ),
                                      items: Sex.map((type) {
                                        return DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedSex = value;

                                        });
                                      },
                                      validator: (value) =>
                                      value == null ? 'Please select gender' : null,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _twoCol(context,
                                    DropdownButtonFormField<String>(
                                    value: _selectedEducation,
                                    dropdownColor: const Color(0xFF22304A),
                                    style: const TextStyle(color: Colors.white),
                                      hint: const Text(
                                        'Select level of education',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    decoration: _inputDecoration(
                                      label: 'Level of Education',
                                      prefix: Icons.cast_for_education,

                                    ),
                                    items: value.levelofeducationlist.map((name) {
                                      return DropdownMenuItem<String>(
                                        value: name.name,
                                        child: Text(name.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedEducation = value;

                                      });
                                    },
                                    validator: (value) =>
                                    value == null ? 'Please select education level' : null,
                                  ),
                                    TextFormField(
                                      controller: _householdController,
                                      style: TextStyle(color: Colors.white),
                                      decoration: _inputDecoration(label: "Household Size",
                                        prefix: Icons.person,
                                        hint: 'Enter household size',),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Enter farmer household size';
                                        }
                                        if (int.tryParse(value) == null) {
                                          return 'Only numbers are allowed';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 14,),
                                  TextFormField(
                                    controller: _homeaddressController,
                                    style: TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(label: "Home Address",
                                      prefix: Icons.home,
                                      hint: 'Enter Home Address',),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Enter farmer Home Address'
                                        : null,
                                  ),
                                  const SizedBox(height: 14,),
                                  TextFormField(
                                    controller: _homegpsController,
                                    style: TextStyle(color: Colors.white70),
                                    decoration: InputDecoration(
                                      labelText: 'GhanaPost GPS Address',
                                      labelStyle: TextStyle(color: Colors.white70),
                                      prefixIcon: Icon(
                                        Icons.location_on,
                                        color: Colors.white70,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.white24,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.blue),
                                      ),
                                      fillColor: const Color(0xFF22304A),
                                      filled: true,
                                      helperText: 'Format: AB-1234-5678',
                                      helperStyle: TextStyle(color: Colors.white70),
                                    ),
                                    inputFormatters: [
                                      TextInputFormatter.withFunction((
                                          oldValue,
                                          newValue,
                                          ) {
                                        String raw = newValue.text
                                            .toUpperCase()
                                            .replaceAll('-', '');
                                        String part1 = '';
                                        String part2 = '';
                                        String part3 = '';
                                        int i = 0;
                                        // Collect up to 2 letters
                                        while (i < raw.length && part1.length < 2) {
                                          if (RegExp(r'[A-Z]').hasMatch(raw[i])) {
                                            part1 += raw[i];
                                          }
                                          i++;
                                        }
                                        // Collect up to 4 digits
                                        while (i < raw.length && part2.length < 4) {
                                          if (RegExp(r'\d').hasMatch(raw[i])) {
                                            part2 += raw[i];
                                          }
                                          i++;
                                        }
                                        // Collect up to 4 more digits
                                        while (i < raw.length && part3.length < 4) {
                                          if (RegExp(r'\d').hasMatch(raw[i])) {
                                            part3 += raw[i];
                                          }
                                          i++;
                                        }
                                        String text = part1;
                                        if (part1.length == 2) text += '-';
                                        text += part2;
                                        if (part2.length == 4) text += '-';
                                        text += part3;
                                        // Limit to max length (2+1+4+1+4 = 12)
                                        if (text.length > 12)
                                          text = text.substring(0, 12);
                                        // Set cursor position
                                        int offset = text.length;
                                        // If user is deleting a dash, move cursor back
                                        if (oldValue.text.endsWith('-') &&
                                            oldValue.text.length > newValue.text.length) {
                                          offset--;
                                        }
                                        return TextEditingValue(
                                          text: text,
                                          selection: TextSelection.collapsed(
                                            offset: offset,
                                          ),
                                        );
                                      }),
                                    ],
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return null;
                                      final ghanaPostReg = RegExp(
                                        r'^[A-Z]{2}-\d{4}-\d{4}$',
                                        caseSensitive: false,
                                      );
                                      if (!ghanaPostReg.hasMatch(v.trim())) {
                                        return 'Enter a valid GhanaPost GPS address (e.g. AB-1234-5678)';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14,),
                                  // REGION
                                  _loadingRegions
                                      ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                      : DropdownButtonFormField<String>(
                                    value: _selectedRegionCode,
                                    dropdownColor: const Color(0xFF22304A),
                                    style: TextStyle(color: Colors.white70),
                                    decoration: InputDecoration(
                                      labelText: 'Region',
                                      labelStyle: TextStyle(color: Colors.white70),
                                      prefixIcon: Icon(
                                        Icons.map,
                                        color: Colors.white70,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.white24,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.blue,
                                        ),
                                      ),
                                      fillColor: const Color(0xFF22304A),
                                      filled: true,
                                    ),
                                    items: _regions
                                        .map(
                                          (r) => DropdownMenuItem<String>(
                                        value: r['regioncode'],
                                        child: Text(r['regionname']),
                                      ),
                                    )
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedRegionCode = val;
                                        _selectedConstituencyCode = null;
                                        _selectedElectoralArea = null;
                                        _selectedRegionName = _regions.firstWhere((r) => r['regioncode'] == val)['regionname'];

                                      });
                                    },
                                    validator: (v) =>
                                    v == null ? 'Select region' : null,
                                  ),
                                  const SizedBox(height: 14),
                                  // CONSTITUENCY
                                  _twoCol(context,
                                  _loadingConstituencies
                                      ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                      :
                                  DropdownButtonFormField<String>(
                                    value: _selectedConstituencyCode,
                                    style: TextStyle(color: Colors.white70),
                                    dropdownColor: const Color(0xFF22304A),
                                    hint: const Text(
                                      'Select district',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    decoration: _inputDecoration(label: "District",prefix: Icons.account_balance,),
                                    items: _filteredConstituencies
                                        .map(
                                          (c) => DropdownMenuItem<String>(
                                        value: c['constcode'],
                                        child: Text(c['constname']),
                                      ),
                                    )
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedConstituencyCode = val;
                                        _selectedElectoralArea = null;
                                        _selectedDistrictName = _filteredConstituencies.firstWhere((c) => c['constcode'] == val)['constname'];

                                      });
                                    },
                                    validator: (v) =>
                                    v == null ? 'Select District' : null,
                                  ),
                                  // ELECTORAL AREA
                                  _loadingElectoralAreas
                                      ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                      : DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedElectoralArea,
                                    style: TextStyle(color: Colors.white70),
                                    dropdownColor: const Color(0xFF22304A),
                                    hint: const Text(
                                      'Select community',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    decoration: _inputDecoration(label: "Community",prefix: Icons.group,),
                                    items: _filteredElectoralAreas
                                        .map(
                                          (ea) => DropdownMenuItem<String>(
                                        value: ea['electoralarea'],
                                        child: Text(ea['electoralarea']),
                                      ),
                                    )
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedElectoralArea = val;

                                      });
                                    },
                                    validator: (v) =>
                                    v == null ? 'Select community' : null,
                                  ),
                                  ),
                                  const SizedBox(height: 14,),
                                  _twoCol(context,
                                      TextFormField(
                                        controller: dobController,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: _inputDecoration(
                                          label: "Date of Birth (DD/MM/YYYY)",prefix: Icons.calendar_today,hint: "Enter date of birth",
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          _DobFormatter(),
                                          LengthLimitingTextInputFormatter(10),
                                        ],
                                        validator: (val) {
                                          if (val == null || val.isEmpty)
                                            return "Required field";
                                          if (val.length != 10)
                                            return "Format: DD/MM/YYYY";

                                          final parts = val.split('/');
                                          if (parts.length != 3) return "Invalid format";

                                          final day = int.tryParse(parts[0]);
                                          final month = int.tryParse(parts[1]);
                                          final year = int.tryParse(parts[2]);

                                          if (day == null ||
                                              month == null ||
                                              year == null) {
                                            return "Invalid date";
                                          }

                                          if (day < 1 || day > 31)
                                            return "Day must be 1-31";
                                          if (month < 1 || month > 12)
                                            return "Month must be 1-12";

                                          final now = DateTime.now();
                                          final dob = DateTime(year, month, day);
                                          final age = now.difference(dob).inDays ~/ 365;

                                          if (age < 18)
                                            return "Must be 18 years or older";

                                          return null;
                                        },
                                      ),
                                      TextFormField(
                                      controller: ghanaCardController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: _inputDecoration(label: 'GHA-000000000-0',prefix: Icons.credit_card),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^[A-Za-z0-9-]*$'),
                                        ),
                                        _GhanaCardFormatter(),
                                        LengthLimitingTextInputFormatter(15),
                                      ],
                                      validator: (val) {
                                        if (val == null || val.isEmpty)
                                          return "Required field";
                                        final pattern = RegExp(r'^GHA-\d{9}-\d$');
                                        if (!pattern.hasMatch(val))
                                          return "Format: GHA-#########-#";
                                        return null;
                                      },
                                    ),
                                      ),
                                  const SizedBox(height: 14),
                                  _twoCol(context,
                                    DropdownButtonFormField<String>(
                                      value: _selectedMajorcrop,
                                      dropdownColor: const Color(0xFF22304A),
                                      style: const TextStyle(color: Colors.white),
                                      hint: const Text(
                                        'Select major crop',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Major Crop',
                                        prefix: Icons.eco,

                                        ),
                                      items: value.crops.map((majorcrop) {
                                        return DropdownMenuItem<String>(
                                          value: majorcrop.name,
                                          child: Text(majorcrop.name),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedMajorcrop = value;

                                        });
                                      },
                                      validator: (value) =>
                                      value == null ? 'Please select major crop' : null,
                                    ),
                                    InputDecorator(
                                      decoration: _inputDecoration(
                                        label: 'Minor Crops',
                                        prefix: Icons.grass,
                                        hint: 'Select minor crops',
                                      ),
                                      child: InkWell(
                                        onTap: () async {
                                          final selected = await showDialog<List<CropModel>>(
                                            context: context,
                                            builder: (_) => MultiSelectDialog<CropModel>(
                                              backgroundColor: const Color(0xFF22304A),
                                              itemsTextStyle: const TextStyle(color: Colors.white),
                                              selectedColor: Colors.blue,
                                                selectedItemsTextStyle: const TextStyle(color: Colors.white),
                                              items: value.crops.map((cropz) =>
                                                  MultiSelectItem(cropz, cropz.name)
                                              ).toList(),
                                              initialValue: _selectedMinorcrop,
                                            ),
                                          );

                                          if (selected != null) {
                                            setState(() {
                                              _selectedMinorcrop = selected;
                                              minorcroplisit = selected.map((e) => e.name).toList();
                                            });
                                          }
                                        },
                                        child: Text(
                                          _selectedMinorcrop.isEmpty
                                              ? 'Select minor crop'
                                              : _selectedMinorcrop.map((e) => e.name).join(', '),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),

                                    ),

                                  ),
                                  const SizedBox(height: 14),
                                  InputDecorator(
                                    decoration: _inputDecoration(
                                      label: 'Languages Spoken',
                                      prefix: Icons.language,
                                      hint: 'Select languages',
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        final selected = await showDialog<List<LanguageModel>>(
                                          context: context,
                                          builder: (_) => MultiSelectDialog<LanguageModel>(
                                            backgroundColor: const Color(0xFF22304A),
                                            itemsTextStyle: const TextStyle(color: Colors.white),
                                            selectedColor: Colors.blue,
                                            selectedItemsTextStyle: const TextStyle(color: Colors.white),
                                            items: value.languages.map((language) =>
                                                MultiSelectItem(language, language.name)
                                            ).toList(),
                                            initialValue: _selectedLanguages,
                                          ),
                                        );

                                        if (selected != null) {
                                          setState(() {
                                            _selectedLanguages = selected;
                                            spokenlanguages = selected.map((e) => e.name).toList();
                                          });
                                        }
                                      },
                                      child: Text(
                                        _selectedLanguages.isEmpty
                                            ? 'Select languages'
                                            : _selectedLanguages.map((e) => e.name).join(', '),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  isSmallholderFarmer ? const SizedBox() :DropdownButtonFormField<String>(
                                      value: _businessRegistered,
                                      dropdownColor: const Color(0xFF22304A),
                                      style: const TextStyle(color: Colors.white),
                                    hint: const Text(
                                      'Select option',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                      decoration: _inputDecoration(
                                        label: 'Business Registered',
                                        prefix: Icons.app_registration_outlined,

                                      ),
                                      items: registered.map((type) {
                                        return DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _businessRegistered = value;

                                        });
                                      },

                                    ),
                                  const SizedBox(height: 14),
                                  if (isBusinessRegistered)
                                    _businessSection(context),
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCustomaType,
                                    dropdownColor: const Color(0xFF22304A),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Customer Type',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.white24),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.blue),
                                      ),
                                      fillColor: const Color(0xFF22304A),
                                      filled: true,
                                    ),
                                    items: _customaTypes.map((type) {
                                      return DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(type),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCustomaType = value;
                                        if (value != 'Credit') {
                                          _creditlimitController.clear();
                                          _selectedpaymentduration = null;
                                        }
                                      });
                                    },
                                    validator: (value) =>
                                    value == null ? 'Please select customer type' : null,
                                  ),
                                  SizedBox(height: 14),
                                  if (isCreditCustomer) ...[
                                    TextFormField(
                                      controller: _creditlimitController,
                                      style: const TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      inputFormatters:  [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')), ],
                                      decoration: InputDecoration(
                                        labelText: 'Credit Limit',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.white24),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.blue),
                                        ),
                                        fillColor: const Color(0xFF22304A),
                                        filled: true,
                                      ),
                                      validator: (value) {
                                        if (!isCreditCustomer) return null;
                                        if (value == null || value.isEmpty) {
                                          return 'Enter valid credit limit'; }
                                        final num? parsed = num.tryParse(value);
                                        if (parsed == null) {
                                          return 'Only numbers are allowed'; }
                                        if (parsed <= 0) { return 'Credit limit must be greater than 0'; }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 14),
                                    /// PAYMENT DURATION
                                    DropdownButtonFormField<String>(
                                      value: _selectedpaymentduration,
                                      dropdownColor: const Color(0xFF22304A),
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Payment Duration',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.white24),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.blue),
                                        ),
                                        fillColor: const Color(0xFF22304A),
                                        filled: true,
                                      ),
                                      items: paymentduration.map((type) {
                                        return DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedpaymentduration = value);
                                      },
                                      validator: (value) {
                                        if (!isCreditCustomer) return null;
                                        return value == null ? 'Please select payment duration' : null;
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 30),

                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      // Save button
                                      SizedBox(
                                        width: 200,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF415A77),
                                            padding:
                                            const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: _loading
                                              ? null
                                              : () async {
                                            if (!_formKey.currentState!.validate())
                                              return;

                                            setState(() => _loading = true);
                                            String name= _nameController.text.trim();
                                            String dob= dobController.text.trim();
                                            String ghcard= ghanaCardController.text.trim();
                                            String contact= _contactController.text.trim();
                                            String popularname= _popularNameController.text.trim();
                                            String businessname= _businnessnameController.text.trim();
                                            String businessaddress= _businessaddressController.text.trim();
                                            String parttimestaff= _parttimestaffController.text.trim();
                                            String fulltimestaff= _fulltimestaffController.text.trim();
                                            final educationlevel= _selectedEducation;
                                            String household= _householdController.text.trim();
                                            String homeaddress= _homeaddressController.text.trim();
                                            final gender= _selectedSex;
                                            String customertype= _selectedCustomerType!['name'];
                                            String customertypeid= _selectedCustomerType!['id'];
                                            final branchId = value.selectedBranch?.id ?? '';
                                            final branchName = value.selectedBranch?.branchname ?? '';
                                            String businessgps= _businessgpsController.text.trim();
                                            String homegps= _homegpsController.text.trim();
                                            final creditlimit= _creditlimitController.text.trim();
                                            final farmerid="$customertypeid${DateTime.now().millisecondsSinceEpoch}";
                                            String docid=value.normalizeAndSanitize("${value.companyid}_${contact}");

                                            final existingDoc = await value .db.collection('customers');
                                            _clearTextFields(){
                                              _nameController.clear();
                                              _contactController.clear();
                                              _popularNameController.clear();
                                              _businnessnameController.clear();
                                              _businessaddressController.clear();
                                              _fulltimestaffController.clear();
                                              _parttimestaffController.clear();
                                              _householdController.clear();
                                              _homeaddressController.clear();
                                              _selectedSex = null;
                                              _selectedEducation = null;
                                              _selectedRegionCode = null;
                                              _selectedConstituencyCode = null;
                                              _selectedElectoralArea = null;
                                              _selectedDistrictName = null;
                                              _selectedRegionName = null;
                                              _selectedMajorcrop = null;
                                              _selectedMinorcrop = [];
                                              minorcroplisit = [];
                                              dobController.clear();
                                              ghanaCardController.clear();
                                              spokenlanguages = [];
                                              _businessRegistered = null;
                                              _selectedLanguages = [];
                                              _businessgpsController.clear();
                                              _homegpsController.clear();

                                              setState(() => _selectedCustomerType = null);
                                            };


                                            try {

                                              if (widget.docId != null) {
                                                final existingDocWithSameContact = await existingDoc
                                                    .where(
                                                  Filter.or(
                                                    Filter('contact', isEqualTo: contact),
                                                    Filter('ghanacard', isEqualTo: ghcard),
                                                  ),
                                                )
                                                    .where('companyid', isEqualTo: value.companyid)
                                                    .where("id", isNotEqualTo: widget.docId)
                                                    .limit(1)
                                                    .get();
                                                if (existingDocWithSameContact .docs.isNotEmpty ) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor:
                                                        Colors.red,
                                                        content: Text
                                                          ("Farmer already exists",
                                                          style: TextStyle
                                                            (
                                                              color: Colors.white
                                                          ),
                                                        )

                                                        ,));
                                                  setState(() => _loading = false);
                                                  return;
                                                }
                                                final id = widget.docId!;
                                                final newCustomer = FarmerRegModel(
                                                    id: id,
                                                    branchname:branchName,
                                                    branchid: branchId,
                                                    name: name,
                                                    contact: contact,
                                                    customertype: customertype,
                                                    iscashcustoma: _selectedCustomaType,
                                                    paymentduration: _selectedpaymentduration,
                                                    creditlimit:creditlimit,
                                                    companyid: value.companyid,
                                                    staff: value.staff,
                                                    date: DateTime.now(),
                                                    updatedby: value.staff,
                                                    updatedat: DateTime.now(),
                                                    deletedat: null,
                                                    companyname: value.company,
                                                    community: _selectedElectoralArea!,
                                                    region:_selectedRegionName!,
                                                    district: _selectedDistrictName!, majorcrop:_selectedMajorcrop!,
                                                    minorcrop: minorcroplisit!,
                                                    businessgps: businessgps,
                                                    homegps: homegps,

                                                    dateofbirth: dob, ghanacard:ghcard, popularname: popularname, household: household, homeaddress: homeaddress, gender: gender!, educationlevel:educationlevel!,
                                                  businessname:businessname,businessaddress:businessaddress,fulltimestaff:fulltimestaff,parttimestaff:parttimestaff,registered:_businessRegistered, farmerid:farmerid, languagespokens:spokenlanguages
                                                );

                                                await existingDoc.doc(id).set(newCustomer.toMap(), SetOptions(merge: true));
                                                _clearTextFields();
                                                Navigator.pop(context);
                                              }

                                              else {
                                                final ref= existingDoc.where('companyid', isEqualTo: value.companyid)// exclude current doc if editing
                                                .where(
                                            Filter.or(
                                            Filter('contact', isEqualTo: contact),
                                            Filter('ghanacard', isEqualTo: ghcard),
                                            ),
                                            ).limit(1).get();;

                                                if (ref != null && (await ref).docs.isNotEmpty) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar
                                                        (backgroundColor:
                                                      Colors.red,
                                                        content: Text
                                                          ("Farmer already exists",
                                                          style: TextStyle
                                                            (color: Colors.white
                                                          )
                                                          ,)
                                                        ,)
                                                  );
                                                  setState(() => _loading = false);
                                                  return;
                                                }
                                                final newCustomer = FarmerRegModel(
                                                  id: docid,
                                                  branchname:branchName,
                                                  branchid:branchId,
                                                  name: name,
                                                  contact: contact,
                                                  customertype: customertype,
                                                  creditlimit: creditlimit,
                                                  paymentduration: _selectedpaymentduration,
                                                    iscashcustoma: _selectedCustomaType,
                                                    companyid: value.companyid,
                                                  staff: value.staff,
                                                  date: DateTime.now(),
                                                  updatedat: null,
                                                  deletedat: null,
                                                  companyname: value.company,
                                                  community:_selectedElectoralArea!,
                                                  region:_selectedRegionName!,
                                                  district: _selectedDistrictName!,
                                                    majorcrop:_selectedMajorcrop!,
                                                    minorcrop: minorcroplisit,
                                                    homegps: homegps,
                                                    businessgps: businessgps,
                                                     dateofbirth: dob, ghanacard:ghcard,
                                                    popularname: popularname, household: household, homeaddress: homeaddress, gender: gender!, educationlevel:educationlevel!,
                                                    businessname:businessname,businessaddress:businessaddress,fulltimestaff:fulltimestaff,parttimestaff:parttimestaff,registered:_businessRegistered, farmerid:farmerid,languagespokens:spokenlanguages
                                                );

                                                await existingDoc.doc(docid).set(newCustomer.toMap());
                                                _clearTextFields();

                                                final smsRecord = {
                                                  'companyid': value.companyid,
                                                  'branchid': value.branchid,
                                                  'staff': value.staff,
                                                  'message': "Welcome to ${value.company},you have been registerd as a ${customertype} with customer ID: ${farmerid}.",
                                                  'senderid': "",
                                                  'recipient': contact,
                                                  'type': 'single',
                                                  'bulkFilterType': null,
                                                  'status': 'pending',
                                                  'successMessage': '',
                                                  'failureReason': '',
                                                  'createdAt': Timestamp.now(),
                                                  'updatedAt': Timestamp.now(),
                                                };

                                                await value.db.collection('sms_logs').add(smsRecord);

                                              }

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Colors.green,
                                                  content: Text(widget.docId == null
                                                      ? "Farmer Registered Successfully"
                                                      : "Farmer Updated Successfully"),
                                                ),
                                              );

                                            } catch (e) {
                                              print(e.toString());
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(e.toString())),
                                              );
                                            }

                                            if (!mounted) return;
                                            setState(() { _loading = false;
                                            _selectedCustomerType = null;
                                            });
                                          },
                                          child: _loading
                                              ? const CircularProgressIndicator(
                                              color: Colors.white)
                                              : Text(
                                            widget.docId == null
                                                ? "Register"
                                                : "Update",
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 200,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.white70),
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: const Icon(Icons.view_list, color: Colors.white70),
                                          label: const Text("View", style: TextStyle(color: Colors.white70)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => FarmerListPage()),
                                            );
                                          },
                                        ),
                                      ),


                                    ],
                                  ),
                                  ],


                              ),
                            ),
                          ),

                        ],
                      )
                  ),
                ),
              ),
            ),
          );
        }
    );
  }
}
class _GhanaCardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final raw = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    if (raw.isEmpty) {
      const text = 'GHA-';
      return const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    String digits = raw;
    if (digits.startsWith('GHA')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('GH')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('G')) {
      digits = digits.substring(1);
    }

    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);

    final buffer = StringBuffer('GHA-');
    if (digits.length < 9) {
      buffer.write(digits);
    } else {
      buffer.write(digits.substring(0, 9));
      buffer.write('-');
      buffer.write(digits.substring(9));
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
class _DobFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Enforce day constraint (max 31)
    if (digits.length >= 2) {
      final day = int.parse(digits.substring(0, 2));
      if (day > 31) {
        digits = '31' + digits.substring(2);
      }
    }

    // Enforce month constraint (max 12)
    if (digits.length >= 4) {
      final month = int.parse(digits.substring(2, 4));
      if (month > 12) {
        digits = digits.substring(0, 2) + '12' + digits.substring(4);
      }
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 3) {
        buffer.write('/');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

