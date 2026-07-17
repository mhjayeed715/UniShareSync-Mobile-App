import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/dispute.dart';

class DisputeDetailsDialog extends StatefulWidget {
  final DisputeType type;
  const DisputeDetailsDialog({super.key, required this.type});

  @override
  State<DisputeDetailsDialog> createState() => _DisputeDetailsDialogState();
}

class _DisputeDetailsDialogState extends State<DisputeDetailsDialog> {
  final _costCtrl = TextEditingController();
  Uint8List? _photoBytes;
  String? _photoName;
  final _formKey = GlobalKey<FormState>();

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoName = file.name;
    });
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDamage = widget.type == DisputeType.damage;
    return AlertDialog(
      title: Text(isDamage ? 'Report Damaged Item' : 'Report Non-Return'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDamage
                    ? 'Please specify the estimated repair/replacement cost and attach evidence photos.'
                    : 'Please specify the claimed value/replacement cost for the item.',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Claimed Cost (BDT)',
                  prefixText: 'BDT ',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a cost';
                  }
                  if (double.tryParse(val) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              if (isDamage) ...[
                const SizedBox(height: 16),
                const Text('Evidence Photo (Required):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (_photoBytes != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _photoBytes!,
                          height: 120,
                          width: 300,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _photoBytes = null;
                            _photoName = null;
                          }),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (isDamage && _photoBytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('At least 1 evidence photo is required for damage disputes.')),
              );
              return;
            }
            Navigator.pop(context, {
              'cost': double.parse(_costCtrl.text.trim()),
              'photoBytes': _photoBytes,
              'photoName': _photoName,
            });
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
