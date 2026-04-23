const String customerServicePublicCategory = 'customer_service';

bool isCustomerServiceCategory(String? rawCategory) {
  final normalized = rawCategory?.trim().toLowerCase() ?? '';
  return normalized == customerServicePublicCategory ||
      normalized == 'customerservice' ||
      normalized == 'service' ||
      normalized == '客服';
}

String? normalizeCustomerServiceCategory(String? rawCategory) {
  final trimmed = rawCategory?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return trimmed;
  }
  if (isCustomerServiceCategory(trimmed)) {
    return customerServicePublicCategory;
  }
  return trimmed;
}
