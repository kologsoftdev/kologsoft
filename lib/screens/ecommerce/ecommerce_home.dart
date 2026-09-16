import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/itemregmodel.dart';
import '../../services/item_cache_service.dart';
import '../../providers/cart_provider.dart';
import 'product_detail_screen.dart';
import 'product_list_screen.dart';
import 'cart_screen.dart';
import 'category_screen.dart';
import 'account_screen.dart';
import 'orders_screen.dart';

class EcommerceHome extends StatefulWidget {
  const EcommerceHome({Key? key}) : super(key: key);

  @override
  State<EcommerceHome> createState() => _EcommerceHomeState();
}

class _EcommerceHomeState extends State<EcommerceHome> {
  final ItemCacheService _itemCacheService = ItemCacheService();
  List<ItemModel> _featuredProducts = [];
  List<ItemModel> _dealsOfDay = [];
  List<String> _categories = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _itemCacheService.getAllItems();

      // Get unique categories
      final categories = items.map((item) => item.pcategory).toSet().toList();

      setState(() {
        _featuredProducts = items.take(10).toList();
        _dealsOfDay = items
            .where(
              (item) =>
                  double.tryParse(item.retailprice) != null &&
                  double.parse(item.retailprice) < 100,
            )
            .take(8)
            .toList();
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1200;
        final isTablet =
            constraints.maxWidth > 600 && constraints.maxWidth <= 1200;

        return Scaffold(
          body: _selectedIndex == 0
              ? _buildHomeContent(isDesktop, isTablet)
              : _selectedIndex == 1
              ? const CategoryScreen()
              : _selectedIndex == 2
              ? const CartScreen()
              : _selectedIndex == 3
              ? const OrdersScreen()
              : const AccountScreen(),
          bottomNavigationBar: constraints.maxWidth <= 600
              ? _buildBottomNav()
              : null,
        );
      },
    );
  }

  Widget _buildHomeContent(bool isDesktop, bool isTablet) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(isDesktop),
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _buildSearchBar(),
          _buildCategoriesSection(isDesktop, isTablet),
          _buildBanner(),
          _buildDealsSection(isDesktop, isTablet),
          _buildFeaturedSection(isDesktop, isTablet),
        ],
      ],
    );
  }

  Widget _buildAppBar(bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 100 : 80,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF131921),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF131921), Color(0xFF232F3E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'KologShop',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131921),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isDesktop) ...[
                    _buildNavItem('Home', 0),
                    _buildNavItem('Categories', 1),
                    _buildNavItem('Orders', 3),
                    _buildNavItem('Account', 4),
                  ],
                  const SizedBox(width: 16),
                  // Cart Icon
                  Consumer<CartProvider>(
                    builder: (context, cart, child) {
                      return IconButton(
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                            ),
                            if (cart.itemCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    '${cart.itemCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () => setState(() => _selectedIndex = 2),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String title, int index) {
    final isSelected = _selectedIndex == index;
    return TextButton(
      onPressed: () => setState(() => _selectedIndex = index),
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? Colors.orange : Colors.white,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: const Color(0xFF232F3E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search products...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
          onSubmitted: (query) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductListScreen(searchQuery: query),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop
        ? 8
        : isTablet
        ? 6
        : 4;

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop by Category',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _categories.take(crossAxisCount).length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _buildCategoryCard(category);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category) {
    return InkWell(
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
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category, size: 32, color: Colors.grey[700]),
              const SizedBox(height: 8),
              Text(
                category,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Big Sale!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Up to 50% OFF',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProductListScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF6B35),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Shop Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealsSection(bool isDesktop, bool isTablet) {
    return _buildProductSection(
      title: "Today's Deals",
      products: _dealsOfDay,
      isDesktop: isDesktop,
      isTablet: isTablet,
    );
  }

  Widget _buildFeaturedSection(bool isDesktop, bool isTablet) {
    return _buildProductSection(
      title: 'Featured Products',
      products: _featuredProducts,
      isDesktop: isDesktop,
      isTablet: isTablet,
    );
  }

  Widget _buildProductSection({
    required String title,
    required List<ItemModel> products,
    required bool isDesktop,
    required bool isTablet,
  }) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductListScreen(),
                      ),
                    );
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: isDesktop ? 220 : 160,
                    margin: const EdgeInsets.only(right: 12),
                    child: _buildProductCard(products[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ItemModel product) {
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
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
                                  size: 40,
                                ),
                              ),
                        ),
                      )
                    : const Center(child: Icon(Icons.shopping_bag, size: 40)),
              ),
            ),
            Padding(
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
                  const SizedBox(height: 4),
                  Text(
                    'GHS ${product.retailprice}',
                    style: const TextStyle(
                      color: Color(0xFFB12704),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (int.parse(product.openingstock) > 0)
                    Text(
                      'In Stock',
                      style: TextStyle(color: Colors.green[700], fontSize: 12),
                    )
                  else
                    Text(
                      'Out of Stock',
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFFF6B35),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.category),
          label: 'Categories',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
      ],
    );
  }
}
