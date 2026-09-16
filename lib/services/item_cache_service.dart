import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/itemregmodel.dart';
import 'dart:async';

class ItemCacheService {
  static const String _boxName = 'itemsCache';
  static const String _lastSyncKey = 'items_last_sync';
  static const String _itemCountKey = 'items_count';

  Box<ItemModel>? _itemsBox;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize Hive box
  Future<void> init() async {
    _itemsBox = await Hive.openBox<ItemModel>(_boxName);
  }

  // Get all cached items
  List<ItemModel> getAllItems() {
    if (_itemsBox == null) return [];
    return _itemsBox!.values.toList();
  }

  // Stream items that match search query (from cache)
  Stream<List<ItemModel>> streamSearchItems(String query) {
    final controller = StreamController<List<ItemModel>>();

    if (_itemsBox == null || query.isEmpty) {
      controller.add([]);
      controller.close();
      return controller.stream;
    }

    final lowerQuery = query.toLowerCase();
    final results = _itemsBox!.values.where((item) {
      return item.name.toLowerCase().contains(lowerQuery) ||
          item.barcode.toLowerCase().contains(lowerQuery);
    }).toList();

    controller.add(results);
    controller.close();

    return controller.stream;
  }

  // Search items by name or barcode
  List<ItemModel> searchItems(String query) {
    if (_itemsBox == null || query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _itemsBox!.values.where((item) {
      return item.name.toLowerCase().contains(lowerQuery) ||
          item.barcode.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Get item by barcode
  ItemModel? getItemByBarcode(String barcode, String companyId) {
    if (_itemsBox == null) return null;

    try {
      return _itemsBox!.values.firstWhere((item) => item.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  // Get item by ID
  ItemModel? getItemById(String id) {
    return _itemsBox?.get(id);
  }

  // Check if sync is needed (sync every 6 hours or if count changed)
  Future<bool> needsSync(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final cachedCount = prefs.getInt(_itemCountKey) ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final sixHoursInMs = 6 * 60 * 60 * 1000;

    // Check if 6 hours passed
    if (now - lastSync > sixHoursInMs) {
      return true;
    }

    // Check if item count changed in Firestore
    try {
      final snapshot = await _firestore.collection('itemsreg').count().get();

      final currentCount = snapshot.count ?? 0;
      if (currentCount != cachedCount) {
        return true;
      }
    } catch (e) {
      print('Error checking item count: $e');
    }

    return false;
  }

  // Sync items from Firestore to Hive cache
  Future<void> syncItems(
    String companyId, {
    bool forceSync = false,
    int retryCount = 3,
  }) async {
    if (_itemsBox == null) {
      await init();
    }

    // Check if sync is needed
    if (!forceSync && !await needsSync(companyId)) {
      print('Sync not needed, cache is up to date');
      return;
    }

    print('Starting item sync for company: $companyId');

    int attempts = 0;
    while (attempts < retryCount) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Get last sync timestamp
        final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
        final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);

        Query query = _firestore.collection('itemsreg');

        // If not force sync and we have a last sync time, only get updated items
        if (!forceSync && lastSync > 0) {
          query = query.where(
            'updatedAt',
            isGreaterThan: Timestamp.fromDate(lastSyncDate),
          );
          print('Fetching items updated after: $lastSyncDate');
        } else {
          print('Performing full sync');
        }

        final snapshot = await query.get(
          const GetOptions(source: Source.server),
        );

        print('Fetched ${snapshot.docs.length} items from Firestore');

        // Update cache using ItemModel
        for (var doc in snapshot.docs) {
          try {
            final item = ItemModel.fromDoc(doc);
            await _itemsBox!.put(item.id, item);
          } catch (e) {
            print('Error parsing item document ${doc.id}: $e');
          }
        }

        // Update sync metadata
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_lastSyncKey, now);
        await prefs.setInt(_itemCountKey, _itemsBox!.length);

        print('Sync completed. Total cached items: ${_itemsBox!.length}');
        return;
      } catch (e) {
        attempts++;
        print('Error syncing items (attempt $attempts): $e');
        if (attempts >= retryCount) {
          // debugPrint('❌ Item sync failed after $retryCount attempts: $e');
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  // Add or update single item in cache
  Future<void> addOrUpdateItem(ItemModel item) async {
    if (_itemsBox == null) {
      await init();
    }
    await _itemsBox!.put(item.id, item);
  }

  // Delete item from cache
  Future<void> deleteItem(String itemId) async {
    if (_itemsBox == null) return;
    await _itemsBox!.delete(itemId);
  }

  // Clear all cached items
  Future<void> clearCache() async {
    if (_itemsBox == null) return;
    await _itemsBox!.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_itemCountKey);
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'totalItems': _itemsBox?.length ?? 0,
      'isInitialized': _itemsBox != null,
    };
  }

  // Close the box
  Future<void> close() async {
    await _itemsBox?.close();
  }
}
