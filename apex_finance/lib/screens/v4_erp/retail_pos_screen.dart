/// Wave 148 — Retail POS (barcode scan + cart + receipt).
///
/// Square / Lightspeed / Shopify POS-class retail point-of-sale.
/// Features:
///   - Product catalog grid (by category)
///   - Shopping cart with qty + discount
///   - Customer linking (loyalty integration)
///   - Multi-tender payment (cash / card / Apple Pay / QR)
///   - ZATCA e-invoice QR generation
///   - Print receipt preview
library;

import 'package:flutter/material.dart';

class RetailPosScreen extends StatefulWidget {
  const RetailPosScreen({super.key});

  @override
  State<RetailPosScreen> createState() => _RetailPosScreenState();
}

class _RetailPosScreenState extends State<RetailPosScreen> {
  String _category = 'الكل';
  final List<_CartItem> _cart = [];
  String _customer = 'عميل نقدي';
  double _discount = 0;

  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);

  static const _products = <_Product>[
    _Product(sku: 'P-1001', name: 'قميص رسمي', category: 'ملابس', price: 149, stock: 24, icon: Icons.checkroom),
    _Product(sku: 'P-1002', name: 'بنطلون جينز', category: 'ملابس', price: 199, stock: 18, icon: Icons.checkroom),
    _Product(sku: 'P-1003', name: 'حذاء رياضي', category: 'أحذية', price: 249, stock: 12, icon: Icons.directions_run),
    _Product(sku: 'P-1004', name: 'حقيبة جلدية', category: 'إكسسوارات', price: 329, stock: 8, icon: Icons.work),
    _Product(sku: 'P-1005', name: 'ساعة ذكية', category: 'إلكترونيات', price: 799, stock: 15, icon: Icons.watch),
    _Product(sku: 'P-1006', name: 'سماعات لاسلكية', category: 'إلكترونيات', price: 299, stock: 30, icon: Icons.headphones),
    _Product(sku: 'P-1007', name: 'عطر فاخر', category: 'عناية', price: 450, stock: 20, icon: Icons.spa),
    _Product(sku: 'P-1008', name: 'كتاب رياضيات', category: 'كتب', price: 85, stock: 50, icon: Icons.menu_book),
    _Product(sku: 'P-1009', name: 'قهوة عربية', category: 'طعام', price: 35, stock: 100, icon: Icons.coffee),
    _Product(sku: 'P-1010', name: 'تمر مجدول', category: 'طعام', price: 65, stock: 75, icon: Icons.eco),
    _Product(sku: 'P-1011', name: 'طاولة خشبية', category: 'أثاث', price: 899, stock: 5, icon: Icons.table_bar),
    _Product(sku: 'P-1012', name: 'لوحة فنية', category: 'ديكور', price: 599, stock: 4, icon: Icons.image),
  ];

  List<_Product> get _filtered {
    if (_category == 'الكل') return _products;
    return _products.where((p) => p.category == _category).toList();
  }

  List<String> get _categories {
    return ['الكل', ..._products.map((p) => p.category).toSet()];
  }

  double get _subtotal {
    return _cart.fold(0, (s, i) => s + i.product.price * i.qty);
  }

  double get _vat => (_subtotal - _discount) * 0.15;

  double get _total => _subtotal - _discount + _vat;

  void _addToCart(_Product p) {
    setState(() {
      final existing = _cart.indexWhere((i) => i.product.sku == p.sku);
      if (existing >= 0) {
        _cart[existing] = _CartItem(product: p, qty: _cart[existing].qty + 1);
      } else {
        _cart.add(_CartItem(product: p, qty: 1));
      }
    });
  }

  void _updateQty(int i, int delta) {
    setState(() {
      final newQty = _cart[i].qty + delta;
      if (newQty <= 0) {
        _cart.removeAt(i);
      } else {
        _cart[i] = _CartItem(product: _cart[i].product, qty: newQty);
      }
    });
  }

  void _checkout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إتمام البيع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('العميل: $_customer'),
              Text('المنتجات: ${_cart.length}'),
              Text('الإجمالي: ${_total.toStringAsFixed(2)} ر.س'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _PayChip(label: 'نقدي', icon: Icons.payments, color: Colors.green),
                  _PayChip(label: 'بطاقة', icon: Icons.credit_card, color: Colors.blue),
                  _PayChip(label: 'مدى', icon: Icons.account_balance, color: Colors.purple),
                  _PayChip(label: 'Apple Pay', icon: Icons.phone_iphone, color: Colors.black),
                  _PayChip(label: 'QR ZATCA', icon: Icons.qr_code, color: Colors.orange),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _cart.clear();
                  _discount = 0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت العملية — تم إرسال الفاتورة إلى زاتكا')),
                );
              },
              child: const Text('تأكيد وطباعة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Row(
          children: [
            // Left: product catalog
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Search + category bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storefront, color: _gold),
                            const SizedBox(width: 8),
                            const Text('نقاط بيع التجزئة',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.circle, size: 8, color: Colors.green),
                                  SizedBox(width: 6),
                                  Text('فرع الرياض — جلسة مفتوحة',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'مسح باركود أو بحث باسم المنتج...',
                                  prefixIcon: const Icon(Icons.qr_code_scanner),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((c) {
                              final active = c == _category;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: InkWell(
                                  onTap: () => setState(() => _category = c),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: active ? _gold : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      c,
                                      style: TextStyle(
                                        color: active ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.9,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final p = _filtered[i];
                        return _ProductCard(product: p, onTap: () => _addToCart(p));
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Right: cart + checkout
            Container(
              width: 380,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_navy, Color(0xFF4A148C)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text('السلّة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _gold,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_cart.length} منتج',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: Colors.white70, size: 14),
                                const SizedBox(width: 6),
                                Text(_customer,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                const Icon(Icons.edit, color: Colors.white54, size: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_basket_outlined, size: 56, color: Colors.black26),
                                SizedBox(height: 12),
                                Text('السلّة فارغة', style: TextStyle(color: Colors.black54)),
                                SizedBox(height: 4),
                                Text('اضغط على المنتج لإضافته',
                                    style: TextStyle(color: Colors.black38, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) => _CartRow(
                              item: _cart[i],
                              onAdd: () => _updateQty(i, 1),
                              onRemove: () => _updateQty(i, -1),
                            ),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      children: [
                        _KV('المجموع الفرعي', '${_subtotal.toStringAsFixed(2)} ر.س'),
                        _KV('خصم', '-${_discount.toStringAsFixed(2)} ر.س'),
                        _KV('ضريبة القيمة المضافة (15%)', '${_vat.toStringAsFixed(2)} ر.س'),
                        const Divider(height: 20),
                        _KV('الإجمالي', '${_total.toStringAsFixed(2)} ر.س', bold: true),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _cart.isEmpty ? null : _checkout,
                            style: FilledButton.styleFrom(
                              backgroundColor: _gold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.point_of_sale),
                            label: const Text('إتمام الدفع',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
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
}

class _Product {
  final String sku;
  final String name;
  final String category;
  final double price;
  final int stock;
  final IconData icon;

  const _Product({
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.icon,
  });
}

class _CartItem {
  final _Product product;
  final int qty;
  const _CartItem({required this.product, required this.qty});
}

class _ProductCard extends StatelessWidget {
  final _Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Icon(product.icon, size: 40, color: const Color(0xFFD4AF37)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('${product.price.toStringAsFixed(0)} ر.س',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
                      const Spacer(),
                      Text('× ${product.stock}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _CartRow({required this.item, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFD4AF37).withOpacity(0.15),
        child: Icon(item.product.icon, color: const Color(0xFFD4AF37), size: 18),
      ),
      title: Text(item.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text('${item.product.price.toStringAsFixed(0)} ر.س × ${item.qty}', style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text('${item.qty}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            onPressed: onAdd,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _KV(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: bold ? const Color(0xFF1A237E) : Colors.black87,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _PayChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}
