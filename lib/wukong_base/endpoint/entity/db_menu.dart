/// Database menu
/// 
/// Used for database SQL operations
class DBMenu {
  /// SQL statement
  final String sql;

  /// Table name
  final String? tableName;

  /// Where clause
  final String? where;

  /// Where arguments
  final List<dynamic>? whereArgs;

  DBMenu({
    required this.sql,
    this.tableName,
    this.where,
    this.whereArgs,
  });
}
