import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _workplacesKey = 'workplaces';
  static const String _inspectionsKey = 'inspections';
  static const String _certificatesKey = 'certificates';
  static const String _invoicesKey = 'invoices';
  static const String _hazardsKey = 'hazards';
  static const String _userKey = 'user';
  static const String _settingsKey = 'settings';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Generic save/load methods
  Future<bool> saveList(String key, List<Map<String, dynamic>> data) async {
    try {
      final jsonString = json.encode(data);
      return await _prefs.setString(key, jsonString);
    } catch (e) {
      return false;
    }
  }

  List<Map<String, dynamic>> loadList(String key) {
    try {
      final jsonString = _prefs.getString(key);
      if (jsonString == null) return [];
      final List<dynamic> decoded = json.decode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveMap(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = json.encode(data);
      return await _prefs.setString(key, jsonString);
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic>? loadMap(String key) {
    try {
      final jsonString = _prefs.getString(key);
      if (jsonString == null) return null;
      return json.decode(jsonString);
    } catch (e) {
      return null;
    }
  }

  // Specific data methods
  Future<bool> saveWorkplaces(List<Map<String, dynamic>> workplaces) {
    return saveList(_workplacesKey, workplaces);
  }

  List<Map<String, dynamic>> loadWorkplaces() {
    return loadList(_workplacesKey);
  }

  Future<bool> saveInspections(List<Map<String, dynamic>> inspections) {
    return saveList(_inspectionsKey, inspections);
  }

  List<Map<String, dynamic>> loadInspections() {
    return loadList(_inspectionsKey);
  }

  Future<bool> saveCertificates(List<Map<String, dynamic>> certificates) {
    return saveList(_certificatesKey, certificates);
  }

  List<Map<String, dynamic>> loadCertificates() {
    return loadList(_certificatesKey);
  }

  Future<bool> saveInvoices(List<Map<String, dynamic>> invoices) {
    return saveList(_invoicesKey, invoices);
  }

  List<Map<String, dynamic>> loadInvoices() {
    return loadList(_invoicesKey);
  }

  Future<bool> saveHazards(List<Map<String, dynamic>> hazards) {
    return saveList(_hazardsKey, hazards);
  }

  List<Map<String, dynamic>> loadHazards() {
    return loadList(_hazardsKey);
  }

  Future<bool> saveUser(Map<String, dynamic> user) {
    return saveMap(_userKey, user);
  }

  Map<String, dynamic>? loadUser() {
    return loadMap(_userKey);
  }

  Future<bool> clearUser() async {
    return await _prefs.remove(_userKey);
  }

  Future<bool> clearAll() async {
    return await _prefs.clear();
  }

  // Settings
  Future<bool> saveSetting(String key, dynamic value) async {
    if (value is String) {
      return await _prefs.setString(key, value);
    } else if (value is int) {
      return await _prefs.setInt(key, value);
    } else if (value is double) {
      return await _prefs.setDouble(key, value);
    } else if (value is bool) {
      return await _prefs.setBool(key, value);
    }
    return false;
  }

  T? loadSetting<T>(String key) {
    return _prefs.get(key) as T?;
  }
}
