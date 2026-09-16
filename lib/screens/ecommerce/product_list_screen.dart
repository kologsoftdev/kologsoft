import 'package:flutter/material.dart';
import '../../models/itemregmodel.dart';
import '../../services/item_cache_service.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  final String? category;
  final String? searchQuery;

  const ProductListScreen({Key? key, this.category, this.searchQuery})
    : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ItemCacheService _itemCacheService = ItemCacheService();
  final TextEditingController _searchController = TextEditingController();

  List<ItemModel> _products = [];
  List<ItemModel> _filteredProducts = [];
  bool _isLoading = true;
  String _sortBy = 'name';
  bool _showFilters = false;

  // Filter options
  RangeValues _priceRange = const RangeValues(0, 1000);
  double _maxPrice = 1000;
  bool _inStockOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.searchQuery != null) {
      _searchController.text = widget.searchQuery!;
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final items = await _itemCacheService.getAllItems();

      // Filter by category if provided
      var filteredItems = widget.category != null
          ? items.where((item) => item.pcategory == widget.category).toList()
          : items;

      // Find max price
      if (filteredItems.isNotEmpty) {
        _maxPrice = filteredItems
            .map((item) => double.tryParse(item.retailprice) ?? 0)
            .reduce((a, b) => a > b ? a : b);
        _priceRange = RangeValues(0, _maxPrice);
      }

      setState(() {
        _products = filteredItems;
        _filteredProducts = filteredItems;
        _isLoading = false;
      });

      // Apply initial search if provided
      if (widget.searchQuery != null) {
        _applyFilters();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      var filtered = _products;

      // Search filter
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        filtered = filtered
            .where(
              (product) =>
                  product.name.toLowerCase().contains(query) ||
                  product.barcode.toLowerCase().contains(query),
            )
            .toList();
      }

      // Price range filter
      filtered = filtered.where((product) {
        final price = double.tryParse(product.retailprice) ?? 0;
        return price >= _priceRange.start && price <= _priceRange.end;
      }).toList();

      // Stock filter
      if (_inStockOnly) {
        filtered = filtered
            .where(
              (product) =>
                  int.tryParse(product.openingstock) != null &&
                  int.parse(product.openingstock) > 0,
            )
            .toList();
      }

      // Sort
      filtered.sort((a, b) {
        switch (_sortBy) {
          case 'price_low':
            return (double.tryParse(a.retailprice) ?? 0).compareTo(
              double.tryParse(b.retailprice) ?? 0,
            );
          case 'price_high':
            return (double.tryParse(b.retailprice) ?? 0).compareTo(
              double.tryParse(a.retailprice) ?? 0,
            );
          case 'name':
          default:
            return a.name.compareTo(b.name);
        }
      });

      _filteredProducts = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1200;
        final isTablet = constraints.maxWidth > 600;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.category ?? 'Products'),
            backgroundColor: const Color(0xFF131921),
            actions: [
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    // Desktop sidebar filters
                    if (isDesktop && _showFilters)
                      Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: _buildFilterPanel(isDesktop),
                      ),
                    // Main content
                    Expanded(
                      child: Column(
                        children: [
                          _buildSearchAndSort(isDesktop, isTablet),
                          if (!isDesktop && _showFilters)
                            _buildFilterPanel(false),
                          Expanded(
                            child: _filteredProducts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off,
                                          size: 80,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No products found',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadProducts,
                                    child: _buildProductGrid(
                                      isDesktop,
                                      isTablet,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchAndSort(bool isDesktop, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      color: Colors.grey[100],
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          // Sort and results count
          Row(
            children: [
              Text(
                '${_filteredProducts.length} ${_filteredProducts.length == 1 ? "product" : "products"}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Text('Sort by: '),
              DropdownButton<String>(
                value: _sortBy,
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Name')),
                  DropdownMenuItem(
                    value: 'price_low',
                    child: Text('Price: Low to High'),
                  ),
                  DropdownMenuItem(
                    value: 'price_high',
                    child: Text('Price: High to Low'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _sortBy = value!);
                  _applyFilters();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _priceRange = RangeValues(0, _maxPrice);
                    _inStockOnly = false;
                    _searchController.clear();
                  });
                  _applyFilters();
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          // Price range
          const Text(
            'Price Range',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: _maxPrice,
            divisions: 20,
            labels: RangeLabels(
              'GHS ${_priceRange.start.toStringAsFixed(0)}',
              'GHS ${_priceRange.end.toStringAsFixed(0)}',
            ),
            onChanged: (values) {
              setState(() => _priceRange = values);
              _applyFilters();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GHS ${_priceRange.start.toStringAsFixed(0)}'),
              Text('GHS ${_priceRange.end.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 24),
          // Stock filter
          CheckboxListTile(
            title: const Text('In Stock Only'),
            value: _inStockOnly,
            onChanged: (value) {
              setState(() => _inStockOnly = value ?? false);
              _applyFilters();
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop
        ? 4
        : isTablet
        ? 3
        : 2;

    return GridView.builder(
      padding: EdgeInsets.all(isDesktop ? 16 : 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: isDesktop ? 16 : 8,
        mainAxisSpacing: isDesktop ? 16 : 8,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ItemModel product) {
    final inStock =
        int.tryParse(product.openingstock) != null &&
        int.parse(product.openingstock) > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      color: Colors.grey[100],
                    ),
                    child: product.imageurl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            child: Image.network(
                              product.imageurl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                    ),
                                  ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.shopping_bag, size: 50),
                          ),
                  ),
                  if (!inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      'GHS ${product.retailprice}',
                      style: const TextStyle(
                        color: Color(0xFFB12704),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (inStock)
                      Text(
                        'Stock: ${product.openingstock}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
