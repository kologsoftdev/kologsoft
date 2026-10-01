import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MomoPaymentFields extends StatelessWidget {
  final String? selectedNetwork;
  final String? momoType;

  final List<String> networks;

  final ValueChanged<String?> onNetworkChanged;
  final ValueChanged<String?> onMomoTypeChanged;

  final Widget? merchantFields;

  final TextEditingController? phoneController;

  const MomoPaymentFields({
    super.key,
    required this.selectedNetwork,
    required this.momoType,
    required this.networks,
    required this.onNetworkChanged,
    required this.onMomoTypeChanged,
    this.merchantFields,
    this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildNetworkDropdown(),
        const SizedBox(height: 10),
        _buildMomoTypeDropdown(),

        const SizedBox(height: 5),

        // Merchant fields
        if (momoType == 'merchant' && merchantFields != null) ...[
          const SizedBox(height: 5),
          merchantFields!,
        ],

        // Hubtel phone
        if (momoType == 'hubtel' && phoneController != null) ...[
          const SizedBox(height: 8),
          _buildPhoneField(),
        ],
      ],
    );
  }

  Widget _buildNetworkDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white,
          width: 0.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedNetwork,
        dropdownColor: const Color(0xFF1E3A5A),
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: 'Select Network',
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
          ),
          prefixIcon: const Icon(
            Icons.sim_card,
            color: Colors.white70,
          ),
          filled: true,
          fillColor: const Color(0xFF1E3A5A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: networks.map((network) {
          return DropdownMenuItem<String>(
            value: network.toLowerCase(),
            child: Row(
              children: [
                Icon(
                  _getNetworkIcon(network),
                  color: _getNetworkColor(network),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  network,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: onNetworkChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a network';
          }

          return null;
        },
      ),
    );
  }

  Widget _buildMomoTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white,
          width: 0.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: momoType,
        dropdownColor: const Color(0xFF1E3A5A),
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: 'Payment Type',
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
          ),
          prefixIcon: const Icon(
            Icons.account_balance_wallet,
            color: Colors.white70,
          ),
          filled: true,
          fillColor: const Color(0xFF1E3A5A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'hubtel',
            child: Text(
              'Hubtel',
              style: TextStyle(color: Colors.white),
            ),
          ),
          DropdownMenuItem(
            value: 'merchant',
            child: Text(
              'Merchant',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
        onChanged: onMomoTypeChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select payment type';
          }

          return null;
        },
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: phoneController,
      style: const TextStyle(
        color: Colors.white70,
      ),
      decoration: _inputDecoration(
        label: 'Phone Number',
        prefix: Icons.phone,
        hint: 'Enter contact number',
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'[0-9+]'),
        ),
        LengthLimitingTextInputFormatter(13),
      ],
      validator: (v) {
        if (v == null || v.isEmpty) {
          return 'Required';
        }

        final cleaned = v.replaceAll(' ', '');

        // +233XXXXXXXXX
        if (cleaned.startsWith('+233')) {
          if (cleaned.length != 13 ||
              !RegExp(r'^\+233\d{9}$').hasMatch(cleaned)) {
            return 'Invalid format. Use +233XXXXXXXXX';
          }
        }

        // 0XXXXXXXXX
        else if (cleaned.startsWith('0')) {
          if (cleaned.length != 10 ||
              !RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
            return 'Invalid format. Use 0XXXXXXXXX';
          }
        }

        else {
          return 'Phone must start with 0 or +233';
        }

        return null;
      },
    );
  }

  IconData _getNetworkIcon(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return Icons.sim_card;

      case 'vodafone':
        return Icons.sim_card;

      case 'airteltigo':
        return Icons.sim_card;

      default:
        return Icons.sim_card;
    }
  }

  Color _getNetworkColor(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return Colors.yellow;

      case 'vodafone':
        return Colors.red;

      case 'airteltigo':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData prefix,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white70,
      ),
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white38,
      ),
      prefixIcon: Icon(
        prefix,
        color: Colors.white70,
      ),
      filled: true,
      fillColor: const Color(0xFF1E3A5F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

}