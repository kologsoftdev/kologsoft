
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' hide Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kologsoft/screens/uploadreceiptview.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import '../providers/Datafeed.dart';

class ReceiptUploadPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? item;

  const ReceiptUploadPage({
    Key? key,
    this.docId,
    this.item,
  }) : super(key: key);

  @override
  State<ReceiptUploadPage> createState() => _ReceiptUploadPageState();
}

class _ReceiptUploadPageState extends State<ReceiptUploadPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final List<Uint8List> _logoBytesList = [];
  final List<File> _logoFileList = [];
  List<String> _existingLogoUrls = [];
  static const int _maxImages     = 10;
  static const int _maxFileSizeMB = 5;
  bool _loading = false;
  static const Map<String, List<int>> _magicBytes = {
    'image/jpeg': [0xFF, 0xD8, 0xFF],
    'image/png' : [0x89, 0x50, 0x4E, 0x47],
    'image/webp': [0x52, 0x49, 0x46, 0x46],
    'image/gif' : [0x47, 0x49, 0x46],
  };

  @override
  void initState() {
    super.initState();
    Future.microtask((){

    });

    if (widget.item != null) {
      final d = widget.item!;
      _nameController.text = d['name'];
      _existingLogoUrls =List<String>.from(d['receiptUrl']??[]);
      print(widget.docId);
    }
  }


  Future<void> pickLogo() async {
    final totalExisting = _existingLogoUrls.length +
        _logoFileList.length +
        _logoBytesList.length;

    if (totalExisting >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxImages images allowed.')),
      );
      return;
    }

    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 85,
    );
    if (pickedFiles.isEmpty) return;

    final List<String> errors = [];
    int added = 0;

    for (final file in pickedFiles) {
      if ((totalExisting + added) >= _maxImages) {
        errors.add('Limit of $_maxImages images reached. Some were skipped.');
        break;
      }

      final bytes    = await file.readAsBytes();
      final filename = file.name;
      final error    = await _validateImageBytes(bytes, filename);

      if (error != null) {
        errors.add(error);
        continue;
      }

      if (kIsWeb) {
        _logoBytesList.add(bytes);
      } else {
        _logoFileList.add(File(file.path));
      }
      added++;
    }

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() {});
  }
  Future<List<String>> uploadLogos(String name) async {
    List<String> urls = [];

    for (int i = 0; i < _logoFileList.length || i < _logoBytesList.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('items')
          .child('${name}_$i.png');

      UploadTask task;

      if (kIsWeb) {
        task = ref.putData(
          _logoBytesList[i],
          SettableMetadata(contentType: 'image/png'),
        );
      } else {
        task = ref.putFile(
          _logoFileList[i],
          SettableMetadata(contentType: 'image/png'),
        );
      }

      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }


  Future<void> deleteImagesFromStorage(List<String> urls) async {
    for (final url in urls) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint("Delete error: $e");
      }
    }
  }
  String _uuid() {
    final rng = Random.secure();
    return List.generate(8, (_) => rng.nextInt(16).toRadixString(16)).join();
  }

  Future<String?> _validateImageBytes(Uint8List bytes, String filename) async {

    final sizeMB = bytes.lengthInBytes / (1024 * 1024);
    if (sizeMB > _maxFileSizeMB) {
      return '"$filename" exceeds ${_maxFileSizeMB}MB.';
    }


    final ext = filename.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      return '"$filename" has an unsupported extension.';
    }


    for (final entry in _magicBytes.entries) {
      final sig = entry.value;
      if (bytes.length >= sig.length) {
        final header = bytes.sublist(0, sig.length);
        bool match = true;
        for (int i = 0; i < sig.length; i++) {
          if (header[i] != sig[i]) { match = false; break; }
        }
        if (match) {

          if (entry.key == 'image/webp') {
            if (bytes.length >= 12 &&
                String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
              return null;
            }
          } else {
            return null;
          }
        }
      }
    }

    return '"$filename" is not a valid image file.';
  }
  Future<void> _savereceipt() async {
    if (!_formKey.currentState!.validate()) return;

    final bool hasNewImages =
        _logoFileList.isNotEmpty || _logoBytesList.isNotEmpty;
    final bool hasAnyImages =
        hasNewImages || _existingLogoUrls.isNotEmpty;

    if (!hasAnyImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload an image',style: TextStyle(color: Theme.of(context).colorScheme.primary),),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final datafeed = context.read<Datafeed>();
      final name     = _nameController.text.trim();

      String sanitize(String input) => input.trim().toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');

      final docId = widget.docId
          ?? '${sanitize(datafeed.companyid)}_${datafeed.staffPosition}_${sanitize(name)}_${DateTime.now().millisecondsSinceEpoch}';

      //  keep track original url
      if (widget.docId != null) {
        final originalUrls =
        List<String>.from(widget.item?['receiptUrl'] ?? []);

      // remove url
        final removedUrls = originalUrls
            .where((url) => !_existingLogoUrls.contains(url))
            .toList();

        if (removedUrls.isNotEmpty) {
          await deleteImagesFromStorage(removedUrls);
        }
      }

      //  Upload newly picked images
      final List<String> newUrls =
      hasNewImages ? await uploadNewImages(docId) : [];

      //  Final URL list =
      final List<String> finalUrls = [
        ..._existingLogoUrls,
        ...newUrls,
      ];

      final data = {
        'name'      : name,
        'id'        : docId,
        'receiptUrl': finalUrls,
        'companyid' : datafeed.companyid,
        'branchid'  : datafeed.branchid,
        'branch'    : datafeed.branch,
        'company'   : datafeed.company,
        'staff'     : datafeed.staff,
        if (widget.docId == null)
          'createdat' : FieldValue.serverTimestamp(),
        if (widget.docId != null)
          'updatedat' : FieldValue.serverTimestamp(),
      };

      await datafeed.db
          .collection('uploadreceipt')
          .doc(docId)
          .set(data, SetOptions(merge: true));
   final index =datafeed.receiptList.indexWhere((u)=>u['id']==docId);
   if(index ==-1){
     datafeed.receiptList.add(data);
   }else{
     datafeed.receiptList[index]=data;
   }
      _nameController.clear();
      setState(() {
        _logoBytesList.clear();
        _logoFileList.clear();
        _existingLogoUrls.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.docId == null
              ? 'Saved successfully!'
              : 'Updated successfully!',style: TextStyle(color: Theme.of(context).colorScheme.primary),),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.docId != null) Navigator.pop(context);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e',style: TextStyle(color: Theme.of(context).colorScheme.primary),), backgroundColor: Colors.red),

        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

//uploading new images
  Future<List<String>> uploadNewImages(String docId) async {
    final List<String> urls = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < _logoBytesList.length; i++) {
      final safeName = '${docId}_${timestamp}_${i}_${_uuid()}.png';
      final ref = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child(safeName);

      final snap = await ref.putData(
        _logoBytesList[i],
        SettableMetadata(contentType: 'image/png'),
      );
      urls.add(await snap.ref.getDownloadURL());
    }

    for (int i = 0; i < _logoFileList.length; i++) {
      final safeName = '${docId}_${timestamp}_${i}_${_uuid()}.png';
      final ref = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child(safeName);

      final snap = await ref.putFile(
        _logoFileList[i],
        SettableMetadata(contentType: 'image/png'),
      );
      urls.add(await snap.ref.getDownloadURL());
    }

    return urls;
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: Text(  widget.docId == null  ? 'Upload Receipt' : 'Edit ${_nameController.text}',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.view_list),
                color: const Color(0xFF415A77),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const uploadReceiptViewPage()),
                  );
                },
              )
            ],
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 1,
              bottom: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(
                        child: _buildField(
                          enabled: widget.docId ==null,
                          _nameController,
                          'Item Name',
                          Icons.label,

                          onChanged: (v) {
                            _formKey.currentState!.validate();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(child: _imagePickerSection()),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _loading ? null :_savereceipt ,
                          child: _loading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                              : const Text(
                            'Save',
                            style: TextStyle(color: Colors.white70),
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

  TextFormField _buildField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool enabled = true,
        bool isNumber = false,
        bool required = true,
        Function(String)? onChanged,
        String? Function(String?)? validator,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return TextFormField(
      enabled: enabled,
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white70),

      validator: (value) {
        if (validator != null) {
          return validator(value);
        }

        if (!required) return null;

        if (value == null || value.isEmpty) {
          return 'Required';
        }

        return null;
      },

      decoration: _inputDecoration(label, icon),
      onChanged: onChanged,
      inputFormatters: inputFormatters,
    );
  }
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF22304A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue),
      ),
    );
  }

  Widget _imagePickerSection() {
    bool hasImage = _logoBytesList.isNotEmpty ||
        _logoFileList.isNotEmpty ||
        _existingLogoUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        const SizedBox(height: 12),

        //  MULTIPLE IMAGE GRID
        GestureDetector(
          onTap: pickLogo,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF22304A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.green : Colors.white24,
                width: hasImage ? 2 : 1,
              ),
            ),
            child: hasImage
                ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Memory images (web)
                ..._logoBytesList.asMap().entries.map((entry) {
                  int index = entry.key;
                  Uint8List img = entry.value;

                  return Stack(
                    children: [
                      Image.memory(
                        img,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _logoBytesList.removeAt(index);
                            });
                          },
                          child: const Icon(Icons.close,
                              color: Colors.red, size: 18),
                        ),
                      ),
                    ],
                  );
                }),

                // File images (mobile)
                ..._logoFileList.asMap().entries.map((entry) {
                  int index = entry.key;
                  File file = entry.value;

                  return Stack(
                    children: [
                      Image.file(
                        file,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _logoFileList.removeAt(index);
                            });
                          },
                          child: const Icon(Icons.close,
                              color: Colors.red, size: 18),
                        ),
                      ),
                    ],
                  );
                }),

                // Existing network images
                ..._existingLogoUrls.asMap().entries.map((entry) {
                  int index = entry.key;
                  String url = entry.value;

                  return Stack(
                    children: [
                      Image.network(
                        url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () async {
                            // Delete from Storage immediately when user taps ×
                            await deleteImagesFromStorage([url]);
                            if (!mounted) return;
                            setState(() {
                              _existingLogoUrls.removeAt(index);
                            });
                          },
                          child: const Icon(Icons.close,
                              color: Colors.red, size: 18),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            )
                : const SizedBox(
              height: 120,
              child: Center(
                child: Icon(
                  Icons.add_photo_alternate,
                  size: 50,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: pickLogo,
              icon: Icon(hasImage ? Icons.add : Icons.upload, size: 18),
              label: Text(hasImage ? 'Add More' : 'Select Images'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),

            if (hasImage) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  // Delete all existing Storage files, then clear local lists
                  if (_existingLogoUrls.isNotEmpty) {
                    await deleteImagesFromStorage(List.from(_existingLogoUrls));
                  }
                  if (!mounted) return;
                  setState(() {
                    _logoBytesList.clear();
                    _logoFileList.clear();
                    _existingLogoUrls.clear();
                  });
                },
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Remove All'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
      ],

    );
  }
}