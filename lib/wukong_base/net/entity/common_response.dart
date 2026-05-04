/// Common response entity for API calls
class CommonResponse<T> {
  final int code;
  final String? msg;
  final T? data;

  CommonResponse({
    required this.code,
    this.msg,
    this.data,
  });

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return CommonResponse(
      code: json['code'] as int? ?? 0,
      msg: json['msg'] as String?,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
    );
  }

  bool get isSuccess => code == 0;
}

/// Common list response
class ListResponse<T> {
  final int code;
  final String? msg;
  final List<T>? list;

  ListResponse({
    required this.code,
    this.msg,
    this.list,
  });

  factory ListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return ListResponse(
      code: json['code'] as int? ?? 0,
      msg: json['msg'] as String?,
      list: (json['list'] as List<dynamic>?)
          ?.map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isSuccess => code == 0;
}
