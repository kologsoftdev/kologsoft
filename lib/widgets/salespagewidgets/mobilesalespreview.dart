import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MobileSalesPreview extends StatelessWidget {
  const MobileSalesPreview({
    super.key,
    required this.cartItems,
    required this.customerCarts,
    required this.currentCartId,
    required this.taxableTotal,
    required this.payableTotal,
    required this.insufficientIndices,
    required this.onSwitchCart,
    required this.onDeleteCart,
    required this.onPrintReceipt,
    required this.onMomo,
    required this.onNewTransaction,
    required this.onCustomerInfo,
    this.onSaveDirect,
    this.saveDirectLabel = 'SAVE DIRECT',
    required this.onRemoveItem,
    required this.posPrint,
  });

  final List<Map<String, dynamic>> cartItems;
  final Map<String, List<Map<String, dynamic>>> customerCarts;
  final String currentCartId;
  final double taxableTotal;
  final double payableTotal;
  final Set<int> insufficientIndices;
  final ValueChanged<String> onSwitchCart;
  final ValueChanged<String> onDeleteCart;
  final VoidCallback onPrintReceipt;
  final VoidCallback onMomo;
  final VoidCallback onNewTransaction;
  final VoidCallback onCustomerInfo;
  final VoidCallback? onSaveDirect;
  final String saveDirectLabel;
  final Function(int index) onRemoveItem;
  final bool posPrint;
  @override
  Widget build(BuildContext context) {
    Widget actionTile({
      required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      required onRemoveItem,

    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF182232)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: customerCarts.length > 1
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 8),
              const Text(
                "Sales Preview",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (customerCarts.length > 1)
                PopupMenuButton<String>(
                  icon: Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cart ${currentCartId.split('_')[1]} (${customerCarts.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  color: const Color(0xFF22304A),
                  itemBuilder: (context) {
                    return customerCarts.keys.map((cartId) {
                      final cartNum = cartId.split('_')[1];
                      final itemCount = customerCarts[cartId]?.length ?? 0;
                      final isActive = cartId == currentCartId;
                      return PopupMenuItem<String>(
                        value: cartId,
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isActive ? Colors.orange : Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cart $cartNum ($itemCount items)',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.orange
                                      : Colors.white,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (!isActive && customerCarts.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDeleteCart(cartId);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  onSelected: onSwitchCart,
                ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),

          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            separatorBuilder: (_, __) =>
            const Divider(color: Colors.white10, thickness: 1, height: 16),
            itemBuilder: (context, index) {
              final item = cartItems[index];
              // print("Checking item at index $index for insufficiency: ${item['item']}");
              final isInsufficient = insufficientIndices.contains(index);
              return _cartItem(item, index, isInsufficient: isInsufficient,  );
            },
          ),

          const SizedBox(height: 30),
          const Divider(color: Colors.white24, height: 30),

          _row("Taxable Amount", "GHC ${taxableTotal.toStringAsFixed(2)}"),

          const SizedBox(height: 6),

          _rowBold("Payable Amount", "GHC ${payableTotal.toStringAsFixed(2)}"),

          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [

              if(posPrint) ...[
                actionTile(
                  label: 'POS PRINT',
                  icon: Icons.print,
                  color: Colors.teal,
                  onTap: onPrintReceipt,
                  onRemoveItem: null,
                ),
              ],
              if (onSaveDirect != null)
                actionTile(
                  label: saveDirectLabel,
                  icon: Icons.save,
                  color: Colors.green,
                  onTap: onSaveDirect!,
                  onRemoveItem: null,
                ),
              actionTile(
                label: 'NEW TRANSACTION',
                icon: Icons.add_shopping_cart,
                color: Colors.lightBlue,
                onTap: onNewTransaction,
                onRemoveItem: null,
              ),
              actionTile(
                label: 'CUSTOMER INFO',
                icon: Icons.person,
                color: Colors.orange,
                onTap: onCustomerInfo,
                onRemoveItem: null,
              ),
            ],
          ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }

  Widget _cartItem(Map<String, dynamic> item, int index, {bool isInsufficient = false}) {
    final name = (item['item'] ?? item['name'] ?? '').toString();
    final mode = (item['mode'] ?? '');
    final price = _parseDouble(item['price']);
    final qty = _parseDouble(item['quantity'] ?? item['qty']);
    final discount = _parseDouble(item['discount']);
    final storedTotal = _parseDouble(
      item['totalamount'] ?? item['totalAmount'],
    );

    final computedTotal = storedTotal > 0
        ? storedTotal
        : (price * qty - discount).clamp(0, double.infinity);
    final primaryColor = isInsufficient ? Colors.redAccent : Colors.white;
    final secondaryColor = isInsufficient ? Colors.redAccent : Colors.white60;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isInsufficient
          ? BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      )
          : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isInsufficient
                ? Colors.red.withOpacity(0.25)
                : Colors.white24,
            child: const Icon(Icons.fastfood, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// NAME + PRICE
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(color: primaryColor, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "GHC ${price.toStringAsFixed(2)}",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                /// QUANTITY
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Quantity",
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                    ),
                    Text(
                      '${qty.toStringAsFixed(0)}$mode',
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                /// TOTAL
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Total",
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                    ),
                    Text(
                      "GHC ${computedTotal.toStringAsFixed(2)}",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                /// DISCOUNT
                if (discount > 0)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Discount",
                          style: TextStyle(color: secondaryColor, fontSize: 12),
                        ),
                      ),
                      Text(
                        "- GHC ${discount.toStringAsFixed(2)}",
                        style: TextStyle(color: primaryColor),
                      ),
                    ],
                  ),

                /// WARNING
                if (isInsufficient)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Insufficient balance',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(
              Icons.delete,
              color: Colors.red,
              size: 20,
            ),
            onPressed: () => onRemoveItem(index),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60)),
        Text(value, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _rowBold(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}