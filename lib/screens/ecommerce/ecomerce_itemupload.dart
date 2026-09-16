import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';



// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'E-Commerce Item Registration',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         fontFamily: 'Inter',
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: const Color(0xFF1A6C8E),
//           primary: const Color(0xFF1A6C8E),
//           secondary: const Color(0xFF2C9B6B),
//         ),
//         useMaterial3: true,
//         inputDecorationTheme: InputDecorationTheme(
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(16),
//             borderSide: BorderSide.none,
//           ),
//           filled: true,
//           fillColor: Colors.grey.shade50,
//           contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
//         ),
//       ),
//       home: const ItemRegistrationPage(),
//     );
//   }
// }

class ItemRegistrationPage extends StatefulWidget {
  const ItemRegistrationPage({super.key});

  @override
  State<ItemRegistrationPage> createState() => _ItemRegistrationPageState();
}

class _ItemRegistrationPageState extends State<ItemRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _comparePriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _weightController = TextEditingController();

  // Form fields
  String? _selectedCategory;
  String? _selectedBrand;
  String? _selectedCondition;
  String _productName = '';
  String _description = '';
  bool _isDigitalProduct = false;
  bool _hasVariants = false;

  // Image upload
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // Categories list
  final List<String> _categories = [
    'Electronics', 'Clothing', 'Books', 'Home & Living',
    'Sports', 'Beauty', 'Toys', 'Automotive', 'Jewelry'
  ];

  final List<String> _brands = [
    'Apple', 'Samsung', 'Nike', 'Adidas', 'Sony', 'LG',
    'Gucci', 'Rolex', 'Generic', 'Other'
  ];

  final List<String> _conditions = [
    'New', 'Like New', 'Very Good', 'Good', 'Acceptable'
  ];

  // Variants
  final List<Map<String, dynamic>> _variants = [];
  final TextEditingController _variantNameController = TextEditingController();
  final TextEditingController _variantPriceController = TextEditingController();
  final TextEditingController _variantStockController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _comparePriceController.dispose();
    _stockController.dispose();
    _weightController.dispose();
    _variantNameController.dispose();
    _variantPriceController.dispose();
    _variantStockController.dispose();
    super.dispose();
  }

  // Pick multiple images from gallery
  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedFiles.length} image(s) added'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to pick images: $e');
    }
  }

  // Pick single image from camera
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured and added'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to capture photo: $e');
    }
  }

  // Remove image from list
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Reorder images (drag and drop)
  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final XFile item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  // Add variant
  void _addVariant() {
    if (_variantNameController.text.trim().isEmpty) {
      _showErrorSnackbar('Please enter variant name');
      return;
    }
    if (_variantPriceController.text.trim().isEmpty) {
      _showErrorSnackbar('Please enter variant price');
      return;
    }

    setState(() {
      _variants.add({
        'name': _variantNameController.text.trim(),
        'price': double.parse(_variantPriceController.text.trim()),
        'stock': int.tryParse(_variantStockController.text.trim()) ?? 0,
      });
      _variantNameController.clear();
      _variantPriceController.clear();
      _variantStockController.clear();
    });
  }

  // Remove variant
  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  // Submit product
  void _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImages.isEmpty) {
      _showErrorSnackbar('Please upload at least one product image');
      return;
    }

    if (_selectedCategory == null) {
      _showErrorSnackbar('Please select a category');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    // Simulate API upload (replace with actual backend call)
    await Future.delayed(const Duration(seconds: 2));

    // Here you would upload images and product data to your server
    // For demo, we'll just show success message

    setState(() {
      _isUploading = false;
    });

    // Show success dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Product Added!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: $_productName'),
            const SizedBox(height: 8),
            Text('Images uploaded: ${_selectedImages.length}'),
            if (_variants.isNotEmpty)
              Text('Variants: ${_variants.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForm();
            },
            child: const Text('Add Another Product'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate back or to product list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6C8E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedImages.clear();
      _variants.clear();
      _productName = '';
      _description = '';
      _selectedCategory = null;
      _selectedBrand = null;
      _selectedCondition = null;
      _isDigitalProduct = false;
      _hasVariants = false;
      _priceController.clear();
      _comparePriceController.clear();
      _stockController.clear();
      _weightController.clear();
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Add New Product',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A6C8E),
        actions: [
          IconButton(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset form',
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Images Section
                  _buildImageUploadSection(),
                  const SizedBox(height: 28),

                  // Basic Information Card
                  _buildSectionCard(
                    title: 'Basic Information',
                    icon: Icons.info_outline,
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Product Name *',
                            hintText: 'Enter product name',
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                          ),
                          onChanged: (value) => _productName = value,
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Product name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe your product in detail...',
                            prefixIcon: Icon(Icons.description_outlined),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          onChanged: (value) => _description = value,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Description is required';
                            }
                            if (value.length < 20) {
                              return 'Please provide at least 20 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pricing & Inventory Card
                  _buildSectionCard(
                    title: 'Pricing & Inventory',
                    icon: Icons.attach_money,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                decoration: const InputDecoration(
                                  labelText: 'Price *',
                                  prefixIcon: Icon(Icons.currency_rupee),
                                  prefixText: '\$ ',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) => value == null || double.tryParse(value) == null
                                    ? 'Valid price required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _comparePriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Compare Price',
                                  hintText: 'Original price',
                                  prefixIcon: Icon(Icons.compare_arrows),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockController,
                                decoration: const InputDecoration(
                                  labelText: 'Stock Quantity *',
                                  prefixIcon: Icon(Icons.inventory_2_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) => value == null || int.tryParse(value) == null
                                    ? 'Valid stock number required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                decoration: const InputDecoration(
                                  labelText: 'Weight (kg)',
                                  prefixIcon: Icon(Icons.fitness_center),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Digital Product'),
                          subtitle: const Text('No shipping required'),
                          value: _isDigitalProduct,
                          onChanged: (value) {
                            setState(() {
                              _isDigitalProduct = value;
                            });
                          },
                          activeColor: const Color(0xFF2C9B6B),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Categories & Attributes
                  _buildSectionCard(
                    title: 'Categories & Attributes',
                    icon: Icons.category_outlined,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            prefixIcon: Icon(Icons.category),
                          ),
                          value: _selectedCategory,
                          items: _categories.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          )).toList(),
                          onChanged: (value) => setState(() => _selectedCategory = value),
                          validator: (value) => value == null ? 'Select a category' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Brand',
                            prefixIcon: Icon(Icons.branding_watermark),
                          ),
                          value: _selectedBrand,
                          items: _brands.map((brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(brand),
                          )).toList(),
                          onChanged: (value) => setState(() => _selectedBrand = value),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Condition',
                            prefixIcon: Icon(Icons.verified_outlined),
                          ),
                          value: _selectedCondition,
                          items: _conditions.map((cond) => DropdownMenuItem(
                            value: cond,
                            child: Text(cond),
                          )).toList(),
                          onChanged: (value) => setState(() => _selectedCondition = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Variants Section (Optional)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.dynamic_form, color: const Color(0xFF1A6C8E)),
                              const SizedBox(width: 12),
                              const Text(
                                'Product Variants',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Switch(
                                value: _hasVariants,
                                onChanged: (value) {
                                  setState(() {
                                    _hasVariants = value;
                                    if (!value) _variants.clear();
                                  });
                                },
                                activeColor: const Color(0xFF1A6C8E),
                              ),
                            ],
                          ),
                          if (_hasVariants) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Add size, color, or other variations',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _variantNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Variant (e.g., Large, Red)',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _variantPriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Price',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _variantStockController,
                                    decoration: const InputDecoration(
                                      labelText: 'Stock',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _addVariant,
                                  icon: const Icon(Icons.add_circle, color: Color(0xFF2C9B6B)),
                                  iconSize: 32,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_variants.isNotEmpty) ...[
                              const Divider(),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _variants.length,
                                separatorBuilder: (_, __) => const Divider(height: 8),
                                itemBuilder: (context, index) {
                                  final variant = _variants[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.label_outline),
                                    title: Text(variant['name']),
                                    subtitle: Text('\$${variant['price']} | Stock: ${variant['stock']}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _removeVariant(index),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _submitProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A6C8E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        'Publish Product',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Uploading product...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: const Color(0xFF1A6C8E)),
                const SizedBox(width: 12),
                const Text(
                  'Product Images',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedImages.length} / 10',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Upload high-quality images (JPG, PNG, WEBP)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Image grid
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(
                height: 130,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  onReorder: _reorderImages,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      key: ValueKey(_selectedImages[index].path),
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_selectedImages[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Upload buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMultipleImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select from Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1A6C8E)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}