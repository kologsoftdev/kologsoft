// import 'package:flutter/material.dart';
//
// class MobileSalesPreview extends StatelessWidget {
//   const MobileSalesPreview({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final List<Map<String, dynamic>> cartItems = [
//       {"name": "Iced Coffee - Large", "price": 5.00, "qty": 1},
//       {"name": "Ham Sandwich", "price": 6.00, "qty": 2},
//       {"name": "Ham Sandwich", "price": 6.00, "qty": 2},
//       {"name": "Ham Sandwich", "price": 6.00, "qty": 2},
//       {"name": "Ham Sandwich", "price": 6.00, "qty": 2},
//     ];
//
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       //margin: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF182232),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//
//           Row(
//             children: const [
//               SizedBox(width: 8),
//               Text(
//                 "Sales Preview",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const Divider(color: Colors.white24, height: 20),
//
//
//           const SizedBox(height: 12),
//
//           ListView.separated(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: cartItems.length,
//             separatorBuilder: (_, __) => const Divider(
//               color: Colors.white10,
//               thickness: 1,
//               height: 16,
//             ),
//             itemBuilder: (context, index) {
//               final item = cartItems[index];
//
//               return _cartItem(
//                 item["name"],
//                 item["price"],
//                 item["qty"],
//               );
//             },
//           ),
//
//
//
//           const SizedBox(height: 30),
//           const Divider(color: Colors.white24, height: 30),
//
//
//           _row("Taxable Amount", "GHC 17.66"),
//
//
//           const SizedBox(height: 6),
//
//           _rowBold("Payable Amount", "GHC 18.36"),
//
//           const SizedBox(height: 18),
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: [
//               SizedBox(
//                 //width: 80,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.teal,
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 16,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius:
//                       BorderRadius.circular(4),
//                     ),
//                   ),
//                   onPressed: (){},
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 4.0, right: 4),
//                     child: Text(
//                       "POS PRINT",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               SizedBox(
//                 //width: 100,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 16,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius:
//                       BorderRadius.circular(4),
//                     ),
//                   ),
//                   onPressed: (){},
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 4.0, right: 4),
//                     child: Text(
//                       "MOMO",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               SizedBox(
//                 //width: 150,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.lightBlue,
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 16,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius:
//                       BorderRadius.circular(4),
//                     ),
//                   ),
//                   onPressed: (){},
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 4.0, right: 4),
//                     child: Text(
//                       "NEW TRANSACTION",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               SizedBox(
//                 //width: 100,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange,
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 16,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius:
//                       BorderRadius.circular(4),
//                     ),
//                   ),
//                   onPressed: (){},
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 4.0, right: 4),
//                     child: Text(
//                       "Customer Info",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//
//           // SizedBox(
//           //   width: double.infinity,
//           //   height: 52,
//           //   child: ElevatedButton(
//           //     style: ElevatedButton.styleFrom(
//           //       backgroundColor: Colors.teal,
//           //       shape: RoundedRectangleBorder(
//           //         borderRadius: BorderRadius.circular(14),
//           //       ),
//           //     ),
//           //     onPressed: () {},
//           //     child: const Text(
//           //       "Charge GHC 18.36",
//           //       style: TextStyle(fontSize: 18),
//           //     ),
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }
//
//   Widget _cartItem(String name, double price, int qty) {
//     return Row(
//       children: [
//         const CircleAvatar(
//           radius: 18,
//           backgroundColor: Colors.white24,
//           child: Icon(Icons.fastfood, size: 18, color: Colors.white),
//         ),
//         const SizedBox(width: 10),
//
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
//                   Text(
//                     "GHC ${price.toStringAsFixed(2)}",
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ],
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text("Quantity", style: const TextStyle(color: Colors.white60, fontSize: 12)),
//                   Text("$qty", style: const TextStyle(color: Colors.white)),
//                 ],
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text("Total", style: const TextStyle(color: Colors.white60, fontSize: 12)),
//                   Text("100,000", style: const TextStyle(color: Colors.white)),
//                 ],
//               ),
//             ],
//           ),
//         ),
//
//
//       ],
//     );
//   }
//
//   Widget _row(String label, String value) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label, style: const TextStyle(color: Colors.white60)),
//         Text(value, style: const TextStyle(color: Colors.white)),
//       ],
//     );
//   }
//
//   Widget _rowBold(String label, String value) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label,
//             style: const TextStyle(
//                 color: Colors.white, fontWeight: FontWeight.bold)),
//         Text(value,
//             style: const TextStyle(
//                 color: Colors.white, fontWeight: FontWeight.bold)),
//       ],
//     );
//   }
// }
//
