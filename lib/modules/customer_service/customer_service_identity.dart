const String customerServiceCategory = 'customer_service';
const String customerServicePublicCategory = customerServiceCategory;

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
    case '\u5ba2\u670d':
      return customerServiceCategory;
    default:
      return normalized;
  }
}

String? normalizeCustomerServiceCategory(String? value) {
  return normalizePublicAccountCategory(value);
}

bool isCustomerServiceCategory(String? value) {
  return normalizePublicAccountCategory(value) == customerServiceCategory;
}