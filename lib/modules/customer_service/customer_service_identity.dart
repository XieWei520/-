const String customerServiceCategory = 'customer_service';

String? normalizePublicAccountCategory(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty) {
    return null;
  }

  final aliasKey = normalized.replaceAll(RegExp(r'[\s_-]+'), '');
  switch (aliasKey) {
    case 'customerservice':
    case 'service':
    case 'customersupport':
    case 'support':
      return customerServiceCategory;
    default:
      return normalized;
  }
}

bool isCustomerServiceCategory(String? value) {
  return normalizePublicAccountCategory(value) == customerServiceCategory;
}
