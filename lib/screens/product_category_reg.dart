import 'package:flutter/material.dart';
import 'package:kologsoft/models/productcategorymodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../providers/routes.dart';

class ProductCategoryReg extends StatefulWidget {
  final Productcategorymodel? category;
  const ProductCategoryReg({super.key, this.category});

  @override
  State<ProductCategoryReg> createState() => _ProductCategoryRegState();
}

class _ProductCategoryRegState extends State<ProductCategoryReg> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _categorynameController = TextEditingController();
  @override
  void initState() {
    super.initState();

    if (widget.category != null) {
      _categorynameController.text = widget.category!.productname;

    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
        builder: (BuildContext context, Datafeed value, Widget? child){
          return Scaffold(
            backgroundColor: const Color(0xFF101A23),
            appBar: AppBar(
              title: Text(widget.category != null ? "EDIT PRODUCT CATEGORY" : "PRODUCT CATEGORY REGISTRATION"),
              backgroundColor: const Color(0xFF0D1A26),
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            body: Center(
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
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _categorynameController,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Category Name',
                                    labelStyle: const TextStyle(
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
                                      ? 'Enter category name'
                                      : null,
                                ),
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
                                          backgroundColor: Colors.blue,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        onPressed: () async {
                                          if (!_formKey.currentState!.validate()) return;

                                          try {
                                            final category = Productcategorymodel(
                                              id: widget.category?.id ?? '',
                                              productname: _categorynameController.text.trim(),
                                              staff: '',
                                              companyid: value.companyid,
                                              companyemail: value.companyemail,
                                              date: DateTime.now(),
                                              updatedat: DateTime.now(),
                                              deletedat: DateTime.now(),
                                              updatedby: '',
                                              deletedby: '',
                                            );

                                            await value.addOrUpdateCategory(category);

                                            if (widget.category != null) {
                                              Navigator.pop(context);
                                            }

                                            _categorynameController.clear();


                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(widget.category != null
                                                    ? 'Category updated successfully'
                                                    : 'Category saved successfully'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Operation failed: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },

                                        child: Text(
                                          widget.category != null ? "Update" : "Add",
                                          style: TextStyle(color: Colors.white),),
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
                                          Navigator.pushNamed(context, Routes.productcateview);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    )
                ),
              ),
            ),
          );
        }
    );
  }
}