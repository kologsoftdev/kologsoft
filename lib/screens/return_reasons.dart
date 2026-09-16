import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/screens/stockingmode_list.dart';
import 'package:provider/provider.dart';

import '../models/stocking_modeModel.dart';
import '../providers/Datafeed.dart';
import 'ReturnReasonList.dart';

class ReturnReasons extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  const ReturnReasons({Key? key,this.docId, this.data}) : super(key: key);

  @override
  State<ReturnReasons> createState() => _ReturnReasonsState();
}

class _ReturnReasonsState extends State<ReturnReasons> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  @override

  initState() {
    super.initState();
    if (widget.data != null) {
      _nameController.text = widget.data!['name'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final formWidth = screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

        return Scaffold(

          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(widget.docId != null ? "Edit Reason" : "Register Reasons"),
            backgroundColor: const Color(0xFF0D1A26),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
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
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [

                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.mode,
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
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Enter reason'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              const SizedBox(height: 32),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                        if (!_formKey.currentState!.validate()) return;
                                        setState(() => _isLoading = true);
                                        final name = _nameController.text.trim();
                                        String docid = value.normalizeAndSanitize("${value.companyid}${name}");
                                        final id = widget.docId ?? docid;


                                        try {
                                          cropModel newMode = cropModel(
                                            name: name,
                                            staff: value.staff,
                                            id:id,
                                            date: DateTime.now(),
                                            companyid: value.companyid,
                                            company:value.company,
                                          );

                                          await value.db
                                              .collection('return_reasons')
                                              .doc(id)
                                              .set(newMode.toMap());

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(widget.docId != null
                                                  ? "Reason updated successfully"
                                                  : "reason saved successfully"),
                                            ),
                                          );

                                          _formKey.currentState!.reset();
                                          _nameController.clear();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Error: ${e.toString()}")),
                                          );
                                        } finally {
                                          setState(() => _isLoading = false);
                                        }
                                      },
                                      child: _isLoading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                          : Text(
                                        widget.docId != null ? "Update" : "Register",
                                        style: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.bold,color: Colors.white),
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
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                      icon: const Icon(Icons.view_list, color: Colors.white70),
                                      label: const Text("View",
                                          style: TextStyle(color: Colors.white70)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ReturnReasonLists()),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )


                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
