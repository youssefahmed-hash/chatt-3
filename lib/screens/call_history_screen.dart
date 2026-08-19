import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/api_service.dart';

/// Call history (voice / video calls involving the current user).
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final calls = await ApiService.getCalls();
      if (!mounted) return;
      setState(() {
        _calls = calls;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s min';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).callHistory),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Could not load:\n$_error'))
          : _calls.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).noCallsYet))
          : ListView.builder(
              itemCount: _calls.length,
              itemBuilder: (context, index) {
                final call = _calls[index];
                final type = call['type'] == 'video'
                    ? Icons.videocam
                    : Icons.call;
                final direction = call['direction'] ?? 'outgoing';

                Color iconColor = theme.colorScheme.secondary;
                if (direction == 'missed' ||
                    direction == 'rejected') {
                  iconColor = Colors.red;
                }

                final l10n = AppLocalizations.of(context);
                final subtitle = [
                  direction == 'outgoing'
                      ? l10n.outgoingCall
                      : direction == 'missed'
                      ? l10n.missedCall
                      : direction == 'rejected'
                      ? l10n.rejectedCall
                      : l10n.incomingCall,
                  if (_formatDuration(
                          (call['duration'] as num?)?.toInt() ?? 0)
                      .isNotEmpty)
                    _formatDuration(
                        (call['duration'] as num?)?.toInt() ?? 0),
                ].join(' · ');

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondary
                        .withValues(alpha: 0.15),
                    child: Icon(type, color: iconColor),
                  ),
                  title: Text(
                      call['name'] ?? AppLocalizations.of(context).unknown),
                  subtitle: Text(
                    '$subtitle · ${_formatTime(DateTime.tryParse(call['startedAt']?.toString() ?? '') ?? DateTime.now())}',
                  ),
                );
              },
            ),
    );
  }
}
