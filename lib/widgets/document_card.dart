import 'package:flutter/material.dart';

import '../models/user_document.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Tappable card for a document Hari recalled or the user saved.
/// Tap → full viewer: the original image (PDFs show summary), the AI
/// summary, and the user's own note (e.g. the doctor's suggestions).
/// Used on the chat screen, the voice screen, and the Documents screen —
/// one widget, three surfaces.
class DocumentCard extends StatelessWidget {
  final UserDocument doc;
  final VoidCallback? onDelete;
  final bool compact;

  const DocumentCard({super.key, required this.doc, this.onDelete, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showDocumentViewer(context, doc, onDelete: onDelete),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: doc.isPdf
                      ? Container(
                          color: cs.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.picture_as_pdf_rounded, color: cs.primary),
                        )
                      : Image.network(
                          ApiService.documentFileUrl(doc.id),
                          headers: ApiService.imageHeaders,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: cs.primary.withValues(alpha: 0.12),
                            child: Icon(Icons.description_rounded, color: cs.primary),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    if (doc.docDate.isNotEmpty)
                      Text(
                        doc.docDate,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen bottom sheet: original file + summary + the user's note.
void showDocumentViewer(BuildContext context, UserDocument doc,
    {VoidCallback? onDelete}) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(doc.title, style: Theme.of(ctx).textTheme.titleLarge),
          if (doc.docDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(doc.docDate,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
            ),
          const SizedBox(height: 14),
          if (!doc.isPdf)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  ApiService.documentFileUrl(doc.id),
                  headers: ApiService.imageHeaders,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator())),
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child: Center(child: Text("Couldn't load the image."))),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Icon(Icons.picture_as_pdf_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(doc.filename)),
              ]),
            ),
          if (doc.note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('YOUR NOTE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.marigold)),
            const SizedBox(height: 6),
            Text(doc.note, style: const TextStyle(height: 1.45)),
          ],
          if (doc.summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('WHAT HARI READ IN IT',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: cs.onSurface.withValues(alpha: 0.55))),
            const SizedBox(height: 6),
            Text(doc.summary,
                style: TextStyle(
                    height: 1.45, color: cs.onSurface.withValues(alpha: 0.8))),
          ],
          if (onDelete != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                onDelete();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Forget this document'),
              style: TextButton.styleFrom(foregroundColor: cs.error),
            ),
          ],
        ],
      ),
    ),
  );
}
