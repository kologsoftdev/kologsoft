import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/screens/product_category_reg.dart';
import 'package:provider/provider.dart';

import '../models/productcategorymodel.dart';
import '../providers/Datafeed.dart';

class ProductCategoryView extends StatefulWidget {
  const ProductCategoryView({super.key});

  @override
  State<ProductCategoryView> createState() => _ProductCategoryViewState();
}

class _ProductCategoryViewState extends State<ProductCategoryView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  List <Productcategorymodel> categoryList=[];
  TextEditingController searchController = TextEditingController();
  String searchText = "";

  Stream<List<Productcategorymodel>> getAllCategories() {
    final provider=Provider.of<Datafeed>(context,listen: false);
    return db.collection('productcategoryreg').where('companyId', isEqualTo: provider.companyid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Productcategorymodel.fromJson(doc.data());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text("REGISTERED PRODUCT CATEGORY"),
        backgroundColor: const Color(0xFF1B263B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          )
        ],
      ),
      body: Column(
        children: [

          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 700,
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search product category...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF182232),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchText = value.toLowerCase();
                  });
                },
              ),
            ),
          ),

          // LIST
          Expanded(
            child: StreamBuilder<List<Productcategorymodel>>(
              stream: getAllCategories(),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Not found"));
                }

                final categoryList = snapshot.data!;

                // FILTERED LIST
                final filteredList = categoryList.where((acc) {
                  return acc.productname.toLowerCase().contains(searchText);
                }).toList();

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredList.length,
                      separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                      itemBuilder: (context, index) {

                        final acc = filteredList[index];

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF182232),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.store,
                                    color: Colors.blue),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.productname,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductCategoryReg(category: acc),
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.edit,
                                        color: Colors.orange),
                                  ),

                                  const SizedBox(width: 8),

                                  InkWell(
                                    onTap: () async {
                                      await db
                                          .collection('productcategoryreg')
                                          .doc(acc.id)
                                          .delete();
                                    },
                                    child: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.red),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
