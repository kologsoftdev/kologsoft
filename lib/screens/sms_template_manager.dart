import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/sms_template.dart';
import '../services/sms_template_service.dart';

class SMSTemplateManagerScreen extends StatefulWidget {
  final String companyId;

  const SMSTemplateManagerScreen({super.key, required this.companyId});

  @override
  State<SMSTemplateManagerScreen> createState() => _SMSTemplateManagerScreenState();
}

class _SMSTemplateManagerScreenState extends State<SMSTemplateManagerScreen> {
  final SmsTemplateService _service = SmsTemplateService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Templates'),
      ),
      body: StreamBuilder<List<SmsTemplate>>(
        stream: _service.streamTemplates(widget.companyId),
        builder: (context, snapshot) {
          print(snapshot.error);
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final list = snapshot.data!;
          if (list.isEmpty) {
            return Center(
              child: TextButton.icon(
                onPressed: () => _showEditDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create first template'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final t = list[index];
              return ListTile(
                title: Text('${t.name} (${t.occasion})'),
                subtitle: Text(t.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditDialog(context, template: t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(context, t),
                    ),
                  ],
                ),
                onTap: () => _showEditDialog(context, template: t),
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: list.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SmsTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete "${t.name}" for ${t.occasion}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteTemplate(t.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template deleted')));
    }
  }

  Future<void> _showEditDialog(BuildContext context, {SmsTemplate? template}) async {
    final occasionController = TextEditingController(text: template?.occasion ?? 'birthday');
    final nameController = TextEditingController(text: template?.name ?? '');
    final messageController = TextEditingController(text: template?.message ?? '');
    final tagController = TextEditingController(text: template?.tag ?? '');

    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(template == null ? 'Create Template' : 'Edit Template'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: occasionController.text,
                items: const [
                  DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
                  DropdownMenuItem(value: 'seasonal', child: Text('Seasonal')),
                  DropdownMenuItem(value: 'new_customer', child: Text('New Customer')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit Transaction')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                ],
                onChanged: (v) => occasionController.text = v ?? occasionController.text,
                decoration: const InputDecoration(labelText: 'Occasion'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Template name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tagController,
                decoration: const InputDecoration(labelText: 'Tag (optional, e.g. christmas)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: messageController,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final message = messageController.text.trim();
              final occasion = occasionController.text.trim();
              final tag = tagController.text.trim().isEmpty ? null : tagController.text.trim();

              if (name.isEmpty || message.isEmpty) return;

              try {
                if (template == null) {
                  await _service.createTemplate(
                    companyId: widget.companyId,
                    occasion: occasion,
                    name: name,
                    message: message,
                    tag: tag,
                  );
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template created')));
                } else {
                  await _service.updateTemplate(template.id, name: name, message: message, tag: tag);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template updated')));
                }
                Navigator.pop(c);
              } catch (e) {
                print(e);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
