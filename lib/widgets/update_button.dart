import 'package:flutter/material.dart';

import '../models/remote_config.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// The update button — badge appears when a newer version exists.
/// Android: Play in-app update. iOS: opens the App Store page.
class UpdateButton extends StatelessWidget {
  final RemoteConfig config;
  const UpdateButton({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UpdateStatus>(
      future: UpdateService.check(config),
      builder: (context, snap) {
        final status = snap.data;
        final needsUpdate = status != null && !status.upToDate;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.system_update),
              tooltip: 'Updates',
              onPressed: status == null
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        isDismissible: false, // don't kill an in-flight download
                        builder: (_) =>
                            _UpdateSheet(status: status, config: config),
                      ),
            ),
            if (needsUpdate)
              const Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(radius: 4, backgroundColor: AppColors.marigold),
              ),
          ],
        );
      },
    );
  }
}

class _UpdateSheet extends StatefulWidget {
  final UpdateStatus status;
  final RemoteConfig config;
  const _UpdateSheet({required this.status, required this.config});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  double? _progress; // null = idle, 0–100 = downloading
  String? _error;

  Future<void> _run() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await UpdateService.launch(
        config: widget.config,
        forced: widget.status.forced,
        onOtaProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // System installer takes over from here; close the sheet.
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = "Couldn't download the update — check your connection "
              'and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final downloading = _progress != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status.upToDate ? "You're up to date ✓" : 'Update available',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('Installed: ${status.installedVersion}  ·  Latest: ${status.latestVersion}'),
          if (status.changelog.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("What's new", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ...status.changelog.map((c) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $c'),
                )),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (!status.upToDate) ...[
            const SizedBox(height: 20),
            if (downloading) ...[
              LinearProgressIndicator(
                  value: _progress! > 0 ? _progress! / 100 : null),
              const SizedBox(height: 8),
              Text(
                _progress! >= 100
                    ? 'Starting installer…'
                    : 'Downloading… ${_progress!.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _run,
                  child: Text(_error == null ? 'Update now' : 'Try again'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
