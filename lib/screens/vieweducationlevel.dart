
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kologsoft/screens/registereducationlevel.dart';
import 'package:provider/provider.dart';
import '../models/levelofeducation.dart';
import '../providers/StockProvider.dart';

class EducationLevelListPage extends StatefulWidget {
  @override
  _EducationLevelListPageState createState() => _EducationLevelListPageState();
}

class _EducationLevelListPageState extends State<EducationLevelListPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  String searchQuery = '';

  void initState(){
    super.initState();
    Future.microtask((){
      context.read<StockProvider>().fetcheducationlevels();

    });
  }

  List<EducationModel> filtereducationlevel(List<EducationModel> educationlist) {
    if (searchQuery.isEmpty) return educationlist;

    final query = searchQuery.toLowerCase();
    return educationlist.where((s) {
      final Name = s.name.toLowerCase();
      final contact = s.staff.toLowerCase();
      return Name.contains(query) || contact.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

    return Consumer<StockProvider>(builder: (BuildContext context, StockProvider value, Widget? child) {
      final registerededucationlevels =filtereducationlevel(value.levelofeducationlist);

      return Scaffold(
        backgroundColor: const Color(0xFF101624),
        appBar: AppBar(
          title: const Text("Registered education levels"),
          backgroundColor: const Color(0xFF1B263B),
          actions: [

          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardWidth),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextFormField(
                    onChanged: (v) => setState(() => searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search levels...',
                      hintStyle: TextStyle(color: Colors.white54),
                      prefixIcon:
                      Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF22304A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 10,),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: registerededucationlevels.length,
                      itemBuilder: (context, index) {
                        final educLevels = registerededucationlevels[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B263B),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text( educLevels.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Staff: ${educLevels.staff ?? ''}\nDate: ${educLevels.date}",
                                        style: const TextStyle(
                                            color: Colors.white70, height: 1.4),
                                      ),
                                    ]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.amber),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>EducationLevelRegistration (
                                        docId: educLevels.id,
                                        data: educLevels.toMap(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Delete mode"),
                                      content: const Text(
                                          "Are you sure you want to delete this record?"),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("Cancel")),
                                        ElevatedButton(
                                            onPressed: () =>  Navigator.pop(context, true),
                                            child: const Text("Delete")),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await db.collection('educationlevel').doc(educLevels.id).delete();
                                    value.levelofeducationlist.removeWhere((test) =>test.id == educLevels.id);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("record deleted")));
                                    setState(() {}); // refresh after delete
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },

    );
  }
}

