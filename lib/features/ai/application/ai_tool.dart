import '../../../domain/models/ai/tool_result.dart';

class AiToolContext {
  const AiToolContext({
    required this.userId,
    required this.userMessage,
    required this.now,
  });

  final String userId;
  final String userMessage;
  final DateTime now;
}

abstract interface class AiTool {
  String get name;

  String get description;

  bool canHandle(AiToolContext context);

  Future<ToolResult> execute(AiToolContext context);
}

class ToolRegistry {
  ToolRegistry(List<AiTool> tools)
    : _tools = Map.fromEntries(tools.map((t) => MapEntry(t.name, t)));

  final Map<String, AiTool> _tools;

  AiTool? getTool(String name) => _tools[name];

  List<AiTool> get all => _tools.values.toList();
}
