import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/listing.dart';
import 'services/listing_service.dart';

class CampusShareCreateScreen extends StatefulWidget {
  const CampusShareCreateScreen({super.key, this.listing});
  final Listing? listing;

  @override
  State<CampusShareCreateScreen> createState() =>
      _CampusShareCreateScreenState();
}

class _CampusShareCreateScreenState extends State<CampusShareCreateScreen> {
  final _service = CampusShareService();
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 1 — Type
  ListingType _type = ListingType.borrow;

  // Step 2 — Details
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  ItemCategory _category = ItemCategory.other;
  ItemCondition _condition = ItemCondition.good;
  final List<String> _semesterTags = [];
  Uint8List? _photoBytes;
  String? _photoName;

  // Step 3 — Terms
  final _penaltyCtrl = TextEditingController(text: '10');
  final _maxPenaltyCtrl = TextEditingController(text: '200');
  final _loanDaysCtrl = TextEditingController(text: '14');
  final _depositCtrl = TextEditingController(text: '0');
  final _rentRateCtrl = TextEditingController(text: '50');
  final _rentDepositCtrl = TextEditingController(text: '500');
  final _priceCtrl = TextEditingController(text: '0');

  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    if (widget.listing != null) {
      _type = widget.listing!.type;
      _titleCtrl.text = widget.listing!.title;
      _descCtrl.text = widget.listing!.description;
      _category = widget.listing!.category;
      _condition = widget.listing!.condition;
      _semesterTags.addAll(widget.listing!.semesterTags);
      _loadTerms();
    }
  }

  Future<void> _loadTerms() async {
    final lid = widget.listing!.id;
    final db = Supabase.instance.client;
    try {
      if (_type == ListingType.borrow) {
        final row = await db.from('loan_terms_borrow').select().eq('listing_id', lid).maybeSingle();
        if (row != null && mounted) {
          setState(() {
            _loanDaysCtrl.text = row['loan_duration_days'].toString();
            _penaltyCtrl.text = row['penalty_per_day_bdt'].toString();
            _maxPenaltyCtrl.text = row['max_penalty_bdt'].toString();
            _depositCtrl.text = (row['deposit_bdt'] ?? 0).toString();
          });
        }
      } else if (_type == ListingType.rent) {
        final row = await db.from('loan_terms_rent').select().eq('listing_id', lid).maybeSingle();
        if (row != null && mounted) {
          setState(() {
            _loanDaysCtrl.text = row['rental_duration_days'].toString();
            _rentRateCtrl.text = row['rental_rate_bdt_per_day'].toString();
            _rentDepositCtrl.text = row['security_deposit_bdt'].toString();
            _penaltyCtrl.text = row['penalty_per_day_bdt'].toString();
            _maxPenaltyCtrl.text = row['max_penalty_bdt'].toString();
          });
        }
      } else {
        final row = await db.from('loan_terms_sell').select().eq('listing_id', lid).maybeSingle();
        if (row != null && mounted) {
          setState(() {
            _priceCtrl.text = row['price_bdt'].toString();
          });
        }
      }
    } catch (e) {
      print('Error loading terms: $e');
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _penaltyCtrl.dispose();
    _maxPenaltyCtrl.dispose();
    _loanDaysCtrl.dispose();
    _depositCtrl.dispose();
    _rentRateCtrl.dispose();
    _rentDepositCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 1) {
      if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
        _snack('Title and description are required.');
        return;
      }
      if (_type != ListingType.sell &&
          _condition == ItemCondition.forParts) {
        _snack('"For Parts" condition is only allowed for Sell listings.');
        return;
      }
    }
    if (_step < 3) {
      setState(() => _step++);
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _publish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final now = DateTime.now();

      // Upload photo if selected
      List<String> photoUrls = widget.listing?.photos ?? const [];
      if (_photoBytes != null && _photoName != null) {
        final path = 'campus_share/$uid/${DateTime.now().millisecondsSinceEpoch}_$_photoName';
        await Supabase.instance.client.storage
            .from('campus-share-photos')
            .uploadBinary(path, _photoBytes!);
        final url = Supabase.instance.client.storage
            .from('campus-share-photos')
            .getPublicUrl(path);
        photoUrls = [url];
      }

      final isEditing = widget.listing != null;
      final listing = Listing(
        id: isEditing ? widget.listing!.id : '',
        userId: uid,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        condition: _condition,
        semesterTags: List.from(_semesterTags),
        photos: photoUrls,
        type: _type,
        status: isEditing ? widget.listing!.status : ListingStatus.available,
        createdAt: isEditing ? widget.listing!.createdAt : now,
        updatedAt: now,
      );

      final db = Supabase.instance.client;
      String lid = '';

      if (isEditing) {
        await _service.updateListing(listing);
        lid = widget.listing!.id;
      } else {
        await _service.createListing(listing);
        // We need the listing id — re-fetch last inserted
        final rows = await db
            .from('campus_share_listings')
            .select('id')
            .eq('user_id', uid)
            .eq('title', listing.title)
            .order('created_at', ascending: false)
            .limit(1) as List<dynamic>;
        if (rows.isNotEmpty) {
          lid = rows.first['id'] as String;
        }
      }

      if (lid.isNotEmpty) {
        if (_type == ListingType.borrow) {
          await db.from('loan_terms_borrow').upsert({
            'listing_id': lid,
            'loan_duration_days': int.tryParse(_loanDaysCtrl.text) ?? 14,
            'penalty_per_day_bdt': double.tryParse(_penaltyCtrl.text) ?? 10,
            'max_penalty_bdt': double.tryParse(_maxPenaltyCtrl.text) ?? 200,
            'deposit_bdt': double.tryParse(_depositCtrl.text) ?? 0,
          });
        } else if (_type == ListingType.rent) {
          await db.from('loan_terms_rent').upsert({
            'listing_id': lid,
            'rental_duration_days': int.tryParse(_loanDaysCtrl.text) ?? 7,
            'rental_rate_bdt_per_day': double.tryParse(_rentRateCtrl.text) ?? 50,
            'security_deposit_bdt': double.tryParse(_rentDepositCtrl.text) ?? 500,
            'penalty_per_day_bdt': double.tryParse(_penaltyCtrl.text) ?? 10,
            'max_penalty_bdt': double.tryParse(_maxPenaltyCtrl.text) ?? 200,
          });
        } else {
          await db.from('loan_terms_sell').upsert({
            'listing_id': lid,
            'price_bdt': double.tryParse(_priceCtrl.text) ?? 0,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Listing updated successfully!' : 'Listing published successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: _back,
        ),
        title: Text(
          ['Select Type', 'Item Details', 'Terms & Pricing', 'Preview'][_step],
          style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            backgroundColor: const Color(0xFFE2E8F0),
            color: const Color(0xFFF97316),
            minHeight: 3,
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _StepType(
              selected: _type,
              onSelect: (t) => setState(() => _type = t)),
          _StepDetails(
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            category: _category,
            condition: _condition,
            semesterTags: _semesterTags,
            type: _type,
            photoBytes: _photoBytes,
            onCategoryChanged: (c) => setState(() => _category = c),
            onConditionChanged: (c) => setState(() => _condition = c),
            onSemesterToggled: (s) => setState(() {
              _semesterTags.contains(s)
                  ? _semesterTags.remove(s)
                  : _semesterTags.add(s);
            }),
            onPhotoChanged: (bytes, name) => setState(() {
              _photoBytes = bytes;
              _photoName = name;
            }),
          ),
          _StepTerms(
            type: _type,
            penaltyCtrl: _penaltyCtrl,
            maxPenaltyCtrl: _maxPenaltyCtrl,
            loanDaysCtrl: _loanDaysCtrl,
            depositCtrl: _depositCtrl,
            rentRateCtrl: _rentRateCtrl,
            rentDepositCtrl: _rentDepositCtrl,
            priceCtrl: _priceCtrl,
          ),
          _StepPreview(
            type: _type,
            title: _titleCtrl.text,
            description: _descCtrl.text,
            category: _category,
            condition: _condition,
            semesterTags: _semesterTags,
            photoBytes: _photoBytes,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _publishing ? null : _next,
          child: _publishing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _step < 3 ? 'Continue' : 'Publish Listing',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ),
    );
  }
}

// ── Step 1: Type ──────────────────────────────────────────────────────────────
class _StepType extends StatelessWidget {
  const _StepType({required this.selected, required this.onSelect});
  final ListingType selected;
  final ValueChanged<ListingType> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('What do you want to do?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        _TypeCard(
          type: ListingType.borrow,
          selected: selected == ListingType.borrow,
          icon: Icons.handshake_rounded,
          color: const Color(0xFF2196F3),
          title: 'Lend (Free Borrow)',
          subtitle: 'Let someone borrow your item for free. Library rules apply.',
          onTap: () => onSelect(ListingType.borrow),
        ),
        const SizedBox(height: 10),
        _TypeCard(
          type: ListingType.rent,
          selected: selected == ListingType.rent,
          icon: Icons.payments_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'Rent (Paid Loan)',
          subtitle: 'Charge a daily/weekly rate. Security deposit required.',
          onTap: () => onSelect(ListingType.rent),
        ),
        const SizedBox(height: 10),
        _TypeCard(
          type: ListingType.sell,
          selected: selected == ListingType.sell,
          icon: Icons.sell_rounded,
          color: const Color(0xFF10B981),
          title: 'Sell (Permanent)',
          subtitle: 'Sell your item at a fixed price. No returns.',
          onTap: () => onSelect(ListingType.sell),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final ListingType type;
  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? color : const Color(0xFF0F172A))),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12.5)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Details ───────────────────────────────────────────────────────────
class _StepDetails extends StatelessWidget {
  const _StepDetails({
    required this.titleCtrl,
    required this.descCtrl,
    required this.category,
    required this.condition,
    required this.semesterTags,
    required this.type,
    required this.photoBytes,
    required this.onCategoryChanged,
    required this.onConditionChanged,
    required this.onSemesterToggled,
    required this.onPhotoChanged,
  });
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final ItemCategory category;
  final ItemCondition condition;
  final List<String> semesterTags;
  final ListingType type;
  final Uint8List? photoBytes;
  final ValueChanged<ItemCategory> onCategoryChanged;
  final ValueChanged<ItemCondition> onConditionChanged;
  final ValueChanged<String> onSemesterToggled;
  final void Function(Uint8List? bytes, String? name) onPhotoChanged;

  static const _categoryLabels = {
    ItemCategory.developmentBoard: 'Dev Board',
    ItemCategory.sensorModule: 'Sensor/Module',
    ItemCategory.measurementTool: 'Measurement Tool',
    ItemCategory.labEquipment: 'Lab Equipment',
    ItemCategory.electronicComponents: 'Components',
    ItemCategory.textbook: 'Textbook',
    ItemCategory.referenceBook: 'Reference Book',
    ItemCategory.other: 'Other',
  };

  @override
  Widget build(BuildContext context) {
    // forParts only for sell
    final availableConditions = type == ListingType.sell
        ? ItemCondition.values
        : ItemCondition.values
            .where((c) => c != ItemCondition.forParts)
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Field(label: 'Title', child: TextField(
          controller: titleCtrl,
          decoration: _inputDec('e.g. Arduino Uno R3'),
        )),
        const SizedBox(height: 12),
        _Field(label: 'Description', child: TextField(
          controller: descCtrl,
          maxLines: 3,
          decoration: _inputDec('Describe the item, its state, and any notes…'),
        )),
        const SizedBox(height: 12),
        _Field(
          label: 'Category',
          child: DropdownButtonFormField<ItemCategory>(
            initialValue: category,
            decoration: _inputDec(''),
            items: ItemCategory.values
                .map((c) => DropdownMenuItem(
                    value: c, child: Text(_categoryLabels[c] ?? c.name)))
                .toList(),
            onChanged: (v) { if (v != null) onCategoryChanged(v); },
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Condition',
          child: Wrap(
            spacing: 8,
            children: availableConditions.map((c) {
              final active = condition == c;
              return ChoiceChip(
                label: Text(c.name),
                selected: active,
                onSelected: (_) => onConditionChanged(c),
                selectedColor: const Color(0xFFF97316),
                labelStyle: TextStyle(
                    color: active ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Semester Tags (multi-select)',
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(12, (i) {
              final sem = 'Semester ${i + 1}';
              final active = semesterTags.contains(sem);
              return FilterChip(
                label: Text('Sem ${i + 1}'),
                selected: active,
                onSelected: (_) => onSemesterToggled(sem),
                selectedColor: const Color(0xFFF97316).withOpacity(0.15),
                checkmarkColor: const Color(0xFFF97316),
                labelStyle: TextStyle(
                    color: active
                        ? const Color(0xFFF97316)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Photo (optional)',
          child: _PhotoPicker(
            photoBytes: photoBytes,
            onPhotoChanged: onPhotoChanged,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

// ── Step 3: Terms ─────────────────────────────────────────────────────────────
class _StepTerms extends StatelessWidget {
  const _StepTerms({
    required this.type,
    required this.penaltyCtrl,
    required this.maxPenaltyCtrl,
    required this.loanDaysCtrl,
    required this.depositCtrl,
    required this.rentRateCtrl,
    required this.rentDepositCtrl,
    required this.priceCtrl,
  });
  final ListingType type;
  final TextEditingController penaltyCtrl;
  final TextEditingController maxPenaltyCtrl;
  final TextEditingController loanDaysCtrl;
  final TextEditingController depositCtrl;
  final TextEditingController rentRateCtrl;
  final TextEditingController rentDepositCtrl;
  final TextEditingController priceCtrl;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (type == ListingType.borrow) ...[
          _Field(label: 'Max Loan Duration (days)',
              child: _NumField(ctrl: loanDaysCtrl, prefixText: null)),
          const SizedBox(height: 12),
          _Field(label: 'Penalty per Day (BDT)',
              child: _NumField(ctrl: penaltyCtrl)),
          const SizedBox(height: 12),
          _Field(label: 'Max Penalty Cap (BDT)',
              child: _NumField(ctrl: maxPenaltyCtrl)),
          const SizedBox(height: 12),
          _Field(label: 'Refundable Deposit (BDT, 0 = none)',
              child: _NumField(ctrl: depositCtrl)),
        ] else if (type == ListingType.rent) ...[
          _Field(label: 'Rental Duration (days)',
              child: _NumField(ctrl: loanDaysCtrl, prefixText: null)),
          const SizedBox(height: 12),
          _Field(label: 'Rental Rate per Day (BDT)',
              child: _NumField(ctrl: rentRateCtrl)),
          const SizedBox(height: 12),
          _Field(label: 'Security Deposit (BDT)',
              child: _NumField(ctrl: rentDepositCtrl)),
          const SizedBox(height: 12),
          _Field(label: 'Late Penalty per Day (BDT)',
              child: _NumField(ctrl: penaltyCtrl)),
          const SizedBox(height: 12),
          _Field(label: 'Max Late Penalty Cap (BDT)',
              child: _NumField(ctrl: maxPenaltyCtrl)),
        ] else ...[
          _Field(label: 'Sell Price (BDT)',
              child: _NumField(ctrl: priceCtrl)),
        ],
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.ctrl, this.prefixText = 'BDT '});
  final TextEditingController ctrl;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
            color: Color(0xFF64748B), fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Step 4: Preview ───────────────────────────────────────────────────────────
class _StepPreview extends StatelessWidget {
  const _StepPreview({
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.semesterTags,
    this.photoBytes,
  });
  final ListingType type;
  final String title;
  final String description;
  final ItemCategory category;
  final ItemCondition condition;
  final List<String> semesterTags;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (type) {
      ListingType.borrow => const Color(0xFF2196F3),
      ListingType.rent => const Color(0xFF8B5CF6),
      ListingType.sell => const Color(0xFF10B981),
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Review your listing',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title.isEmpty ? '(No title)' : title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(type.name,
                        style: TextStyle(
                            color: typeColor, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(description.isEmpty ? '(No description)' : description,
                  style: const TextStyle(
                      color: Color(0xFF475569), height: 1.4)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _PreviewChip(label: category.name, color: const Color(0xFF64748B)),
                  _PreviewChip(label: condition.name, color: const Color(0xFF64748B)),
                  ...semesterTags.map((s) =>
                      _PreviewChip(label: s, color: const Color(0xFF8B5CF6))),
                ],
              ),
              if (photoBytes != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    photoBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Photo Picker ─────────────────────────────────────────────────────────────
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photoBytes, required this.onPhotoChanged});
  final Uint8List? photoBytes;
  final void Function(Uint8List? bytes, String? name) onPhotoChanged;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    onPhotoChanged(bytes, file.name);
  }

  @override
  Widget build(BuildContext context) {
    if (photoBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              photoBytes!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => onPhotoChanged(null, null),
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
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _pick(context, ImageSource.camera),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pick(context, ImageSource.gallery),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFFF97316)),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFFF97316)),
            label: const Text('Gallery',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF97316))),
          ),
        ),
      ],
    );
  }
}

// ── Shared field wrapper ──────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                fontSize: 13)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
