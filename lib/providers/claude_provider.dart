import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ai/claude_service.dart';

final claudeServiceProvider = Provider<ClaudeService>((_) => ClaudeService());
