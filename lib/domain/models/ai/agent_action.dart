import 'tool_result.dart';

enum AgentActionStatus { queued, running, succeeded, failed }

class AgentAction {
  const AgentAction({
    required this.id,
    required this.toolName,
    required this.input,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.result,
    this.errorMessage,
  });

  final String id;
  final String toolName;
  final Map<String, Object?> input;
  final AgentActionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final ToolResult? result;
  final String? errorMessage;

  AgentAction copyWith({
    AgentActionStatus? status,
    DateTime? completedAt,
    ToolResult? result,
    String? errorMessage,
  }) {
    return AgentAction(
      id: id,
      toolName: toolName,
      input: input,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'toolName': toolName,
      'input': input,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'result': result?.toJson(),
      'errorMessage': errorMessage,
    };
  }

  factory AgentAction.fromJson(Map<String, Object?> json) {
    return AgentAction(
      id: json['id'] as String? ?? '',
      toolName: json['toolName'] as String? ?? 'unknown',
      input:
          (json['input'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
      status: AgentActionStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => AgentActionStatus.failed,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      result: json['result'] is Map
          ? ToolResult.fromJson((json['result'] as Map).cast<String, Object?>())
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
