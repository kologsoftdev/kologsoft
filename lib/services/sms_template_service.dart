import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sms_template.dart';

class SmsTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col => _firestore.collection('sms_templates');

  Stream<List<SmsTemplate>> streamTemplates(String companyId) {
    return _col
        .where('companyid', isEqualTo: companyId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SmsTemplate.fromDoc(d)).toList());
  }

  Future<List<SmsTemplate>> getTemplatesByOccasion(String companyId, String occasion) async {
    final snap = await _col
        .where('companyid', isEqualTo: companyId)
        .where('occasion', isEqualTo: occasion)
        .orderBy('updatedAt', descending: true)
        .get();

    return snap.docs.map((d) => SmsTemplate.fromDoc(d)).toList();
  }

  Future<SmsTemplate?> getTemplate(String companyId, String occasion, {String? tag}) async {
    Query query = _col
        .where('companyid', isEqualTo: companyId)
        .where('occasion', isEqualTo: occasion)
        .orderBy('updatedAt', descending: true)
        .limit(1);

    if (tag != null) {
      query = _col
          .where('companyid', isEqualTo: companyId)
          .where('occasion', isEqualTo: occasion)
          .where('tag', isEqualTo: tag)
          .orderBy('updatedAt', descending: true)
          .limit(1);
    }

    final snap = await query.get();
    if (snap.docs.isEmpty) return null;
    return SmsTemplate.fromDoc(snap.docs.first);
  }

  Future<DocumentReference> createTemplate({
    required String companyId,
    required String occasion,
    required String name,
    required String message,
    String? tag,
  }) async {
    final now = Timestamp.now();

    final docId =
        '${companyId.trim()}_${occasion.trim().toLowerCase().replaceAll(' ', '_')}';

    final docRef = _col.doc(docId);

    await docRef.set({
      'companyid': companyId,
      'occasion': occasion,
      'name': name,
      'message': message,
      'tag': tag,
      'createdAt': now,
      'updatedAt': now,
    });

    return docRef;
  }
  Future<void> updateTemplate(String id, {required String name, required String message, String? tag}) {
    return _col.doc(id).update({
      'name': name,
      'message': message,
      'tag': tag,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteTemplate(String id) {
    return _col.doc(id).delete();
  }
}
