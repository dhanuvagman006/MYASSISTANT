import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../models/user_document.dart';
import '../models/vision_result.dart';
import '../widgets/document_card.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Screen 04 — Group B: Camera, Photos and Documents.
///
///   B1 Photo questions   — capture/share a photo, ask about it
///   B2 Document reading  — PDFs & document photos summarized + Q&A
///   B3 Scan to text      — OCR with copy-to-clipboard
///   B4 Screenshot helper — event posters become one-tap reminders
///
/// The file uploads once per question (backend is stateless for privacy —
/// nothing is stored server-side); Q&A history rides along as text so
/// follow-ups stay cheap and contextual.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _picker = ImagePicker();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<int>? _bytes;
  String _filename = '';
  String _mime = '';
  bool get _isPdf => _mime == 'application/pdf';

  final List<ChatMessage> _thread = [];
  VisionAction? _pendingAction;
  bool _busy = false;
  bool _saving = false;
  String? _error;

  /// Documents already in Hari's long-term memory (server-side).
  List<UserDocument> _saved = const [];

  @override
  void initState() {
    super.initState();
    _refreshSaved();
  }

  Future<void> _refreshSaved() async {
    try {
      final docs = await ApiService.fetchDocuments();
      if (mounted) setState(() => _saved = docs);
    } catch (_) {/* signed-out or offline — the section just stays hidden */}
  }

  // ---------------- SAVE TO HARI'S MEMORY ----------------

  /// Ask for an optional note (e.g. the doctor's suggestions), then upload.
  /// From then on any chat — typed or voice — can recall this document.
  Future<void> _saveToMemory() async {
    final bytes = _bytes;
    if (bytes == null || _saving) return;
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Save to Hari\'s memory'),
          content: TextField(
            controller: c,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText:
                  'Optional note — e.g. what the doctor suggested, what to take, when to come back…',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Save')),
          ],
        );
      },
    );
    if (note == null || !mounted) return; // cancelled
    setState(() => _saving = true);
    try {
      await ApiService.uploadDocument(
          bytes: bytes, filename: _filename, mimeType: _mime, note: note);
      await _refreshSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Saved. Just ask me later — "show me that report" — and I\'ll pull it up.')));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = "Couldn't save that. Sign in and check your connection.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSaved(UserDocument d) async {
    try {
      await ApiService.deleteDocument(d.id);
      await _refreshSaved();
    } catch (_) {}
  }

  // ---------------- FILE PICKING ----------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        // Downscale before upload: a 12 MP photo becomes ~1 MB with no
        // loss of readability for OCR/Q&A — 10x faster on mobile data.
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 82,
      );
      if (x == null) return;
      _loadFile(await x.readAsBytes(), x.name, 'image/jpeg');
    } catch (_) {
      setState(() => _error = 'Could not open the camera or gallery.');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final r = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final path = r?.files.single.path;
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 18 * 1024 * 1024) {
        setState(() =>
            _error = 'That PDF is too large — up to about 50 pages works best.');
        return;
      }
      _loadFile(bytes, r!.files.single.name, 'application/pdf');
    } catch (_) {
      setState(() => _error = 'Could not open that file.');
    }
  }

  void _loadFile(List<int> bytes, String name, String mime) {
    setState(() {
      _bytes = bytes;
      _filename = name;
      _mime = mime;
      _thread.clear();
      _pendingAction = null;
      _error = null;
    });
    // Auto-analyze on arrival:
    //   images → screenshot mode (describes it AND detects event posters, B4)
    //   PDFs   → plain-language summary (B2)
    _ask(auto: true);
  }

  // ---------------- ASKING ----------------

  Future<void> _ask({bool auto = false, String mode = ''}) async {
    final bytes = _bytes;
    if (bytes == null || _busy) return;
    final question = auto ? '' : _input.text.trim();
    if (!auto && mode.isEmpty && question.isEmpty) return;

    final effectiveMode = mode.isNotEmpty
        ? mode
        : auto
            ? (_isPdf ? 'ask' : 'screenshot')
            : 'ask';

    setState(() {
      _busy = true;
      _error = null;
      if (question.isNotEmpty) {
        _thread.add(ChatMessage(role: 'user', content: question));
        _input.clear();
      }
    });
    _scrollDown();

    try {
      final r = await ApiService.visionAsk(
        bytes: bytes,
        filename: _filename,
        mimeType: _mime,
        mode: effectiveMode,
        question: question,
        history: _thread.length > 1
            ? _thread.sublist(0, _thread.length - 1)
            : const [],
      );
      if (!mounted) return;
      setState(() {
        if (effectiveMode == 'ocr') {
          _showOcrSheet(r.answer);
        } else {
          _thread.add(ChatMessage(role: 'assistant', content: r.answer));
          _pendingAction = r.action ?? _pendingAction;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't analyze that. Check your connection.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  // ---------------- B3: OCR SHEET ----------------

  void _showOcrSheet(String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scanned text',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: SingleChildScrollView(
                  child: SelectableText(
                      text.isEmpty ? 'No text found in this image.' : text),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy all'),
                onPressed: text.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Copied to clipboard')));
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- B4: EVENT → REMINDER ----------------

  Future<void> _approveAction(VisionAction a) async {
    try {
      final when = a.start;
      final text = a.location == null || a.location!.isEmpty
          ? a.title
          : '${a.title} — ${a.location}';
      await ApiService.createReminder(text, when);
      ReminderNotifications.instance.sync(); // schedules the notification
      if (!mounted) return;
      setState(() => _pendingAction = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(when == null
              ? 'Saved "${a.title}"'
              : 'Saved "${a.title}" for ${_fmt(when)}')));
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't save that. Try again.");
      }
    }
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h12 = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h12:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final hasFile = _bytes != null;
    return Column(
      children: [
        if (!hasFile && _saved.isNotEmpty) _savedStrip(),
        Expanded(
          child: hasFile ? _threadView() : _emptyState(),
        ),
        if (hasFile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _saving ? null : _saveToMemory,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bookmark_add_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'Remember this'),
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.danger)),
          ),
        if (hasFile) _inputBar(),
      ],
    );
  }

  /// Horizontal strip of everything Hari already remembers.
  Widget _savedStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HARI REMEMBERS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55))),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _saved.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: DocumentCard(
                  doc: _saved[i],
                  compact: true,
                  onDelete: () => _deleteSaved(_saved[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner_outlined,
                size: 56, color: AppColors.peacock),
            const SizedBox(height: 14),
            Text('Point the camera at anything',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Ask about a photo, get a plain-language summary of a PDF, '
              'copy printed text, or turn an event poster into a reminder.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _bigButton(Icons.photo_camera_rounded, 'Camera',
                    () => _pickImage(ImageSource.camera)),
                _bigButton(Icons.photo_library_rounded, 'Gallery',
                    () => _pickImage(ImageSource.gallery)),
                _bigButton(
                    Icons.picture_as_pdf_rounded, 'PDF', _pickPdf),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigButton(IconData icon, String label, VoidCallback onTap) {
    return FilledButton.tonalIcon(
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      onPressed: onTap,
    );
  }

  Widget _threadView() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [
        _fileCard(),
        const SizedBox(height: 8),
        for (final m in _thread) _bubble(m),
        if (_pendingAction != null) _actionCard(_pendingAction!),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4))),
          ),
      ],
    );
  }

  Widget _fileCard() {
    return Card(
      child: ListTile(
        leading: Icon(
            _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            color: AppColors.peacock),
        title: Text(_filename,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_isPdf ? 'Document' : 'Photo'),
        trailing: Wrap(
          spacing: 0,
          children: [
            if (!_isPdf)
              IconButton(
                tooltip: 'Copy text (OCR)',
                icon: const Icon(Icons.copy_all_rounded),
                onPressed: _busy ? null : () => _ask(mode: 'ocr'),
              ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _bytes = null;
                _thread.clear();
                _pendingAction = null;
                _error = null;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? AppColors.peacock : AppColors.mist,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          m.content,
          style: TextStyle(
              color: isUser ? Colors.white : AppColors.ink, height: 1.45),
        ),
      ),
    );
  }

  /// B4 — the extracted event awaiting the user's approval. Nothing is
  /// saved until they tap Add.
  Widget _actionCard(VisionAction a) {
    return Card(
      color: AppColors.marigold.withValues(alpha: 0.12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.event_available_rounded,
                  color: AppColors.marigold),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(a.title,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 6),
            if (a.start != null)
              Text(_fmt(a.start!),
                  style: const TextStyle(fontSize: 13.5)),
            if (a.location != null && a.location!.isNotEmpty)
              Text(a.location!,
                  style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 10),
            Row(children: [
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add reminder'),
                onPressed: () => _approveAction(a),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _pendingAction = null),
                child: const Text('Dismiss'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'New file',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _busy
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        builder: (ctx) => SafeArea(
                          child: Wrap(children: [
                            ListTile(
                                leading:
                                    const Icon(Icons.photo_camera_rounded),
                                title: const Text('Camera'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickImage(ImageSource.camera);
                                }),
                            ListTile(
                                leading:
                                    const Icon(Icons.photo_library_rounded),
                                title: const Text('Gallery'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickImage(ImageSource.gallery);
                                }),
                            ListTile(
                                leading:
                                    const Icon(Icons.picture_as_pdf_rounded),
                                title: const Text('PDF'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickPdf();
                                }),
                          ]),
                        ),
                      ),
            ),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _ask(),
                decoration: InputDecoration(
                  hintText: 'Ask about this ${_isPdf ? 'document' : 'photo'}…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              icon: const Icon(Icons.arrow_upward_rounded),
              onPressed: _busy ? null : _ask,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
