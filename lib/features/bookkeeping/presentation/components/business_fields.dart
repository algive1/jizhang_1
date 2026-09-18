import 'package:flutter/material.dart';

/// Optional business metadata. Values belong to a transaction, not a CRM entity.
class BusinessFields extends StatelessWidget {
  const BusinessFields({
    super.key,
    required this.invoice,
    required this.customer,
    required this.project,
    required this.supplier,
  });
  final TextEditingController invoice, customer, project, supplier;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final field in [
        ('发票', invoice),
        ('客户', customer),
        ('项目', project),
        ('供应商', supplier),
      ])
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            key: ValueKey('business-${field.$1}'),
            controller: field.$2,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: field.$1,
              counterText: '',
              isDense: true,
            ),
          ),
        ),
    ],
  );
}
