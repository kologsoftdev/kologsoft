import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kologsoft/providers/StockProvider.dart';
import 'package:provider/provider.dart';
import '../view_communities.dart';

class communityRegistration extends StatefulWidget {
  final String? docId;
  final Map<String,dynamic>? data;
  const communityRegistration({super.key,this.docId, this.data});

  @override
  State<communityRegistration> createState() => _communityRegistrationState();
}

class _communityRegistrationState extends State<communityRegistration> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _communityController = TextEditingController();
  String? _selectedRegionName;
  String? _selectedDistrictName;

  bool _loading=false;

  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _constituencies = [];
  List<Map<String, dynamic>> _electoralAreas = [];

  String? _selectedRegionCode;
  String? _selectedConstituencyCode;
  bool _loadingRegions = true;
  bool _loadingConstituencies = true;

  String? _areaName;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRegionData();
  }

  Future _loadRegionData() async {
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
        _electoralAreas = List<Map<String, dynamic>>.from(jsonDecode(eaStr));
        _loadingRegions = false;
        _loadingConstituencies = false;
      });
      if (widget.data != null) {
        final customadata = widget.data!;

        final match = _regions.where((r) => r['regionname'] == customadata['region'],).toList();
        final matchdistrict = _constituencies.where((d) => d['constname'] == customadata['district'],).toList();
        final matchcommunity = _electoralAreas.where((c) => c['constname'] == customadata['community'],).toList();

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

    });

    if (widget.data != null) {
      final customadata = widget.data!;
      _selectedDistrictName = customadata['constname'];
      _selectedRegionName = customadata['regionname'];
      _communityController.text = customadata['electoralarea'];
    }

  }
  @override
  void dispose() {
    _communityController.dispose();

    super.dispose();
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


  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
        builder: (BuildContext context, StockProvider value, Widget? child){
          return Scaffold(
            backgroundColor: const Color(0xFF101A23),
            appBar: AppBar(
              title: Text(widget.docId != null ? "Edit Community Registration" : "Community Registration"),
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
                                        _selectedRegionName = _regions.firstWhere((r) => r['regioncode'] == val)['regionname'];

                                      });
                                    },
                                    validator: (v) =>
                                    v == null ? 'Select region' : null,
                                  ),
                                  const SizedBox(height: 14),
                                  // CONSTITUENCY
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
                                          _selectedDistrictName = _filteredConstituencies.firstWhere((c) => c['constcode'] == val)['constname'];

                                        });
                                      },
                                      validator: (v) =>
                                      v == null ? 'Select District' : null,
                                    ),

                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _communityController,
                                    style: TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      label: 'Community Name',
                                      prefix: Icons.person,
                                      hint: 'Input community name',
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Enter community name'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
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
                                            String community= _communityController.text.trim();


                                            String docid=value.normalizeAndSanitize("${value.companyid}_${community}");

                                            final existingDoc = await value .db.collection('communities');
                                            _clearTextFields(){
                                              _communityController.clear();
                                              _selectedRegionCode = null;
                                              _selectedConstituencyCode = null;
                                              _selectedDistrictName = null;
                                              _selectedRegionName = null;

                                            };


                                            try {

                                              if (widget.docId != null) {

                                                final id = widget.docId!;
                                                final communitydata={
                                                  "regioncode":_selectedRegionCode,
                                                  "regionname":_selectedRegionName,
                                                  "constcode":_selectedConstituencyCode,
                                                  "constname":_selectedDistrictName,
                                                  "electoralarea":community,
                                                  "staff": value.staff,
                                                  "date": DateTime.now(),
                                                  "companyname": value.company,
                                                  "companyid": value.companyid,
                                                  "id": id
                                                };

                                                 await existingDoc.doc(id).set(communitydata, SetOptions(merge: true));
                                                _clearTextFields();
                                                Navigator.pop(context);
                                              }

                                              else {

                                                final communitydata={
                                                  "regioncode":_selectedRegionCode,
                                                  "regionname":_selectedRegionName,
                                                  "constcode":_selectedConstituencyCode,
                                                  "constname":_selectedDistrictName,
                                                  "electoralarea":community,
                                                  "staff": value.staff,
                                                  "date": DateTime.now(),
                                                  "companyname": value.company,
                                                  "companyid": value.companyid,
                                                  "id":docid
                                                };


                                                await existingDoc.doc(docid).set(communitydata);
                                                _clearTextFields();
                                              }

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Colors.green,
                                                  content: Text(widget.docId == null
                                                      ? "Community Registered Successfully"
                                                      : "Community Updated Successfully"),
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
                                                  builder: (_) => CommunityListPage()),
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

