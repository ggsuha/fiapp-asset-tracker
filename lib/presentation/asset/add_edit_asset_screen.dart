import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';

class AddEditAssetScreen extends ConsumerStatefulWidget {
  const AddEditAssetScreen({super.key, required this.walletId, this.assetId});

  final String walletId;
  final String? assetId;

  bool get isEdit => assetId != null;

  @override
  ConsumerState<AddEditAssetScreen> createState() => _AddEditAssetScreenState();
}

class _AddEditAssetScreenState extends ConsumerState<AddEditAssetScreen> {
  static const _bgTop = Color(0xFFF2F7F3);
  static const _bgBottom = Color(0xFFEFF6F1);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _priceController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  AssetType _type = AssetType.custom;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(assetRepositoryProvider);

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    try {
      if (widget.isEdit) {
        await repo.editAsset(
          assetId: widget.assetId!,
          name: _nameController.text.trim(),
          type: _type,
          currency: 'IDR',
          quantity: quantity,
          price: price,
          note: note,
        );
      } else {
        await repo.createAsset(
          walletId: widget.walletId,
          name: _nameController.text.trim(),
          type: _type,
          currency: 'IDR',
          quantity: quantity,
          price: price,
          note: note,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetAsync = widget.assetId == null
        ? const AsyncValue<Asset?>.data(null)
        : ref.watch(assetProvider(widget.assetId!));
    final snapshotAsync = widget.assetId == null
        ? const AsyncValue<AssetSnapshot?>.data(null)
        : ref.watch(
            assetSnapshotProvider((
              walletId: widget.walletId,
              assetId: widget.assetId!,
            )),
          );

    if (widget.assetId != null && !_initialized) {
      final asset = assetAsync.asData?.value;
      final snapshot = snapshotAsync.asData?.value;

      if (asset != null && snapshot != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _initialized) {
            return;
          }
          setState(() {
            _nameController.text = asset.name;
            _type = AssetType.fromDb(asset.type);
            _quantityController.text = snapshot.currentQuantity.toString();
            _priceController.text = snapshot.currentPrice.toString();
            _initialized = true;
          });
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Asset' : 'Add Asset')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white,
                ),
                child: Text(
                  widget.isEdit
                      ? 'Update your asset values and metadata'
                      : 'Create a new asset in this wallet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: AssetType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.dbValue),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              const InputDecorator(
                decoration: InputDecoration(labelText: 'Currency'),
                child: Text('IDR'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save'),
              ),
              if (widget.assetId != null) ...[
                const SizedBox(height: 8),
                Text(
                  'State is event-sourced. Save creates ADJUSTMENT/PRICE_UPDATE events.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Preview: ${asMoney((double.tryParse(_quantityController.text) ?? 0) * (double.tryParse(_priceController.text) ?? 0))}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
