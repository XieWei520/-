import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum AppFailureKind { unauthorized, timeout, network, server, unknown }

@immutable
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final AppFailureKind kind;
  final String message;
  final int? statusCode;

  factory AppFailure.fromDio(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final responseMessage = _extractResponseMessage(exception.response?.data);

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppFailure(
          kind: AppFailureKind.timeout,
          message: exception.message ?? 'Request timed out',
          statusCode: statusCode,
        );
      case DioExceptionType.connectionError:
        return AppFailure(
          kind: AppFailureKind.network,
          message: exception.message ?? 'Network connection failed',
          statusCode: statusCode,
        );
      case DioExceptionType.badResponse:
        if (statusCode == 401) {
          return const AppFailure(
            kind: AppFailureKind.unauthorized,
            message: 'Unauthorized',
            statusCode: 401,
          );
        }
        return AppFailure(
          kind: AppFailureKind.server,
          message: responseMessage ?? exception.message ?? 'Server error',
          statusCode: statusCode,
        );
      default:
        return AppFailure(
          kind: AppFailureKind.unknown,
          message:
              responseMessage ?? exception.message ?? 'Unknown request failure',
          statusCode: statusCode,
        );
    }
  }

  static String describe(
    Object error, {
    String fallbackMessage = 'Request failed',
  }) {
    if (error is AppFailure) {
      return _normalizeMessage(error.message, fallbackMessage);
    }
    if (error is DioException) {
      final inner = error.error;
      if (inner is AppFailure) {
        return _normalizeMessage(inner.message, fallbackMessage);
      }
      return _normalizeMessage(
        _extractResponseMessage(error.response?.data) ??
            error.message ??
            error.toString(),
        fallbackMessage,
      );
    }
    return _normalizeMessage(error.toString(), fallbackMessage);
  }

  static String _normalizeMessage(String? value, String fallbackMessage) {
    final message = _stripKnownPrefix(value?.trim() ?? '');
    return message.isEmpty ? fallbackMessage : message;
  }

  static String _stripKnownPrefix(String value) {
    const prefixes = <String>['Exception: '];
    for (final prefix in prefixes) {
      if (value.startsWith(prefix)) {
        return value.substring(prefix.length).trim();
      }
    }
    return value;
  }

  static String? _extractResponseMessage(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is Map) {
      final message = data['msg'] ?? data['message'];
      final resolved = message?.toString().trim() ?? '';
      return resolved.isEmpty ? null : resolved;
    }
    if (data is String) {
      final body = data.trim();
      if (body.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final message = decoded['msg'] ?? decoded['message'];
          final resolved = message?.toString().trim() ?? '';
          if (resolved.isNotEmpty) {
            return resolved;
          }
        }
      } catch (_) {
        return body;
      }
      return body;
    }
    return null;
  }
}
