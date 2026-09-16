import 'package:flutter/material.dart';
import '../../models/itemregmodel.dart';
import '../../services/item_cache_service.dart';
import 'product_list_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({Key? key}) : super(key: key);

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ItemCacheService _itemCacheService = ItemCacheService();
  Map<String, List<ItemModel>> _categorizedProducts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final items = await _itemCacheService.getAllItems();

      // Group products by category
      final Map<String, List<ItemModel>> categorized = {};
      for (var item in items) {
        if (!categorized.containsKey(item.pcategory)) {
          categorized[item.pcategory] = [];
        }
        categorized[item.pcategory]!.add(item);
      }

      setState(() {
        _categorizedProducts = categorized;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
        backgroundColor: const Color(0xFF131921),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1200;
                final isTablet = constraints.maxWidth > 600;
                final crossAxisCount = isDesktop
                    ? 4
                    : isTablet
                    ? 3
                    : 2;

                return RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: _categorizedProducts.isEmpty
                      ? const Center(child: Text('No categories found'))
                      : GridView.builder(
                          padding: EdgeInsets.all(isDesktop ? 24 : 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 1.1,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: _categorizedProducts.keys.length,
                          itemBuilder: (context, index) {
                            final category = _categorizedProducts.keys
                                .elementAt(index);
                            final products = _categorizedProducts[category]!;
                            return _buildCategoryCard(
                              category,
                              products,
                              isDesktop,
                            );
                          },
                        ),
                );
              },
            ),
    );
  }

  Widget _buildCategoryCard(
    String category,
    List<ItemModel> products,
    bool isDesktop,
  ) {
    final firstProduct = products.firstWhere(
      (p) => p.imageurl.isNotEmpty,
      orElse: () => products.first,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductListScreen(category: category),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.grey[100]!, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: firstProduct.imageurl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            firstProduct.imageurl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.category,
                              size: isDesktop ? 80 : 60,
                              color: Colors.grey[400],
                            ),
                          ),
                        )
                      : Icon(
                          Icons.category,
                          size: isDesktop ? 80 : 60,
                          color: Colors.grey[400],
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      category,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${products.length} ${products.length == 1 ? "item" : "items"}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
