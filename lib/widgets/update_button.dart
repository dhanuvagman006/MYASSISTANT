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
                        builder: (_) => _UpdateSheet(status: status),
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

class _UpdateSheet extends StatelessWidget {
  final UpdateStatus status;
  const _UpdateSheet({required this.status});

  @override
  Widget build(BuildContext context) {
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
          if (!status.upToDate) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await UpdateService.launch(forced: status.forced);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Update now'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
