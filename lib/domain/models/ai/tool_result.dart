class ToolResult {
  const ToolResult({
    required this.toolName,
    required this.success,
    required this.summary,
    this.data = const <String, Object?>{},
  });

  final String toolName;
  final bool success;
  final String summary;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() {
    return {
      'toolName': toolName,
      'success': success,
      'summary': summary,
      'data': data,
    };
  }

  factory ToolResult.fromJson(Map<String, Object?> json) {
    return ToolResult(
      toolName: json['toolName'] as String? ?? 'unknown',
      success: json['success'] as bool? ?? false,
      summary: json['summary'] as String? ?? '',
      data:
          (json['data'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
  }
}
