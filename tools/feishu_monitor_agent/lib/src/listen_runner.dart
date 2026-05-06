import 'agent_models.dart';
import 'browser_controller.dart';
import 'heartbeat_runner.dart';
import 'message_dedupe_store.dart';

class ListenRunResult {
  const ListenRunResult({
    required this.routeCount,
    required this.observedCount,
    required this.reportedCount,
  });

  final int routeCount;
  final int observedCount;
  final int reportedCount;
}

class ListenRunner {
  ListenRunner({
    required this.api,
    required this.browser,
    required this.dedupeStore,
    required this.now,
  });

  final AgentApiLike api;
  final BrowserControllerLike browser;
  final MessageDedupeStore dedupeStore;
  final DateTime Function() now;

  Future<ListenRunResult> runOnce(AgentConfig config) async {
    final observedAt = now().toUtc().toIso8601String();
    final status = await browser.checkStatus();
    await api.reportBrowserStatus(
      agentToken: config.agentToken,
      request: BrowserStatusReportRequest(
        agentId: config.agentId,
        platform: 'feishu',
        browser: 'chromium',
        profileMode: 'isolated_persistent',
        loginStatus: status,
        observedAt: observedAt,
        errorMessage: '',
      ),
    );

    if (status != BrowserLoginStatus.loggedIn) {
      return const ListenRunResult(
        routeCount: 0,
        observedCount: 0,
        reportedCount: 0,
      );
    }

    final routes = await api.fetchAssignedRoutes(agentToken: config.agentToken);
    var observedCount = 0;
    var reportedCount = 0;

    for (final route in routes) {
      final messages = await browser.observeRoute(
        route: route,
        observedAt: observedAt,
      );
      observedCount += messages.length;
      for (final message in messages) {
        final dedupeKey = '${route.routeId}:${message.sourceMessageId}';
        if (!await dedupeStore.markIfNew(dedupeKey)) {
          continue;
        }
        await api.reportObservedMessage(
          agentToken: config.agentToken,
          request: ObservedMessageRequest(
            agentId: config.agentId,
            routeId: route.routeId,
            sourcePlatform: route.platform,
            sourceChatName: route.sourceChatName,
            sourceMessageId: message.sourceMessageId,
            messageType: message.messageType,
            content: message.content,
            sourceCreatedAt: message.sourceCreatedAt,
            observedAt: message.observedAt,
          ),
        );
        reportedCount += 1;
      }
    }

    return ListenRunResult(
      routeCount: routes.length,
      observedCount: observedCount,
      reportedCount: reportedCount,
    );
  }
}
