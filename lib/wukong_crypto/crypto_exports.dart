// Crypto module exports for the still-unfrozen Signal/E2EE scaffold.
//
// Audit status (2026-04-16): placeholder-only. Do not wire this barrel into
// production runtime paths until the backend/API contract is frozen.

// Models
export 'models/signal_data.dart';

// E2EE preview scaffold
export 'e2ee/e2ee_cipher.dart';
export 'e2ee/e2ee_envelope.dart';
export 'e2ee/e2ee_message_codec.dart';
export 'e2ee/e2ee_rollout_policy.dart';

// Service (to be implemented)
// export 'crypto_service.dart';

// API
export '../service/api/crypto_api.dart';
