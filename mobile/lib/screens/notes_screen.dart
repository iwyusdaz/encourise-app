import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../utils/encourise_theme.dart';

/// Displays all saved notes for the current student, grouped by topic.
class NotesScreen extends StatefulWidget {
  final bool isTab;
  final int refreshToken;
  final Future<List<Map<String, dynamic>>> Function()? notesLoader;
  final Future<void> Function(String id)? noteDeleter;

  const NotesScreen({
    super.key,
    this.isTab = false,
    this.refreshToken = 0,
    this.notesLoader,
    this.noteDeleter,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchCtrl.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    final notes = widget.notesLoader != null
        ? await widget.notesLoader!()
        : await _loadNotesFromDatabase();
    if (mounted) {
      setState(() {
        _notes = notes;
        _filteredNotes = notes;
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadNotesFromDatabase() async {
    final db = DatabaseService.instance;
    final student = await db.getStudent();
    final studentId = student?['id'] as String? ?? 'unknown';
    return db.getNotes(studentId);
  }

  void _filterNotes() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = _notes;
      } else {
        _filteredNotes = _notes.where((n) {
          final content = (n['content_text'] as String? ?? '').toLowerCase();
          final topic = (n['topic_id'] as String? ?? '').toLowerCase();
          return content.contains(query) || topic.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteNote(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        ),
        title: Text(
          'Hapus Catatan?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Catatan ini akan dihapus permanen.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: EncouriseColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: EncouriseColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: EncouriseColors.error),
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.noteDeleter != null) {
        await widget.noteDeleter!(id);
      } else {
        await DatabaseService.instance.deleteNote(id);
      }
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  if (!widget.isTab)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: EncouriseColors.surface,
                            borderRadius: BorderRadius.circular(
                              EncouriseRadius.sm,
                            ),
                            boxShadow: EncouriseShadows.soft,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: EncouriseColors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Catatan',
                          style: EncouriseTextStyles.sectionTitle,
                        ),
                        if (_notes.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: EncouriseGradients.primary,
                              borderRadius: BorderRadius.circular(
                                EncouriseRadius.pill,
                              ),
                            ),
                            child: Text(
                              '${_notes.length}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: EncouriseColors.textOnPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: EncouriseSearchBar(
                hintText: 'Cari catatan...',
                controller: _searchCtrl,
              ),
            ),

            const SizedBox(height: 16),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: EncouriseColors.primary,
                        backgroundColor: EncouriseColors.primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    )
                  : _filteredNotes.isEmpty
                  ? _buildEmptyState()
                  : _buildNotesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchCtrl.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: EncouriseGradients.primary,
                shape: BoxShape.circle,
                boxShadow: EncouriseShadows.elevated,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.note_alt_outlined,
                size: 38,
                color: EncouriseColors.textOnDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching ? 'Tidak ditemukan' : 'Belum ada catatan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: EncouriseColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Coba kata kunci lain.'
                  : 'Simpan penjelasan Budi yang berguna saat belajar nanti.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: EncouriseColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final note in _filteredNotes) {
      final topic = note['topic_id'] as String? ?? 'Umum';
      grouped.putIfAbsent(topic, () => []).add(note);
    }

    final topics = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: topics.length,
      itemBuilder: (context, i) {
        final topic = topics[i];
        final notes = grouped[topic]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 24),
            // Topic header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: EncouriseGradients.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      size: 14,
                      color: EncouriseColors.textOnDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    topic,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: EncouriseColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: EncouriseColors.primarySurface,
                      borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                    ),
                    child: Text(
                      '${notes.length}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: EncouriseColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Note cards
            ...notes.map((note) => _buildNoteCard(note)),
          ],
        );
      },
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final content = note['content_text'] as String? ?? '';
    final createdAt = note['created_at'] as String? ?? '';
    final id = note['id'] as String;

    String dateLabel = '';
    try {
      final dt = DateTime.parse(createdAt);
      dateLabel =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: EncouriseColors.textPrimary,
              height: 1.6,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: EncouriseColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                dateLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: EncouriseColors.textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _deleteNote(id),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: EncouriseColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: EncouriseColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
