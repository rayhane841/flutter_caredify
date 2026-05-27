import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_provider.dart';
import '../utils/theme_helper.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'emergency_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  String _searchQuery = '';
  List<Map<String, dynamic>> _cardiologists = [];
  bool _isLoading = true;
  String? _myCardiologistLabel;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _loadCardiologists();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCardiologists() async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context);
    try {
      final userId = _supabase.auth.currentUser?.id;

      if (userId != null) {
        final patientData = await _supabase
            .from('patients')
            .select('cardiologist')
            .eq('id', userId)
            .maybeSingle();
        _myCardiologistLabel = patientData?['cardiologist'] as String?;
      }

      // ✅ Filtre ajouté : status = 'active'
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, specialty, hospital_clinic')
          .eq('role', 'carediologue')
          .eq('status', 'active') // ← MODIFICATION ICI
          .order('full_name', ascending: true);

      if (!mounted) return;

      final List<Map<String, dynamic>> loaded = (response as List).map((c) {
        final fullName = (c['full_name'] ?? 'Inconnu').toString().trim();
        final specialty = (c['specialty'] ?? 'Cardiologue').toString().trim();
        final hospital = (c['hospital_clinic'] ?? '').toString().trim();
        final label = specialty.isNotEmpty
            ? 'Dr. $fullName - $specialty'
            : 'Dr. $fullName';

        return {
          'id': c['id'].toString(),
          'name': 'Dr. $fullName',
          'full_name': fullName,
          'specialty': specialty,
          'hospital': hospital,
          'label': label,
          'available': true,
          'rating': 4.7,
          'lastMessage': l10n.t('tap_to_start_conversation'),
          'lastMessageTime': '',
          'unread': 0,
          'isMyCardiologist': _myCardiologistLabel != null &&
              (_myCardiologistLabel!
                      .toLowerCase()
                      .contains(fullName.toLowerCase()) ||
                  label.toLowerCase() == _myCardiologistLabel!.toLowerCase()),
        };
      }).toList();

      if (userId != null) {
        for (final doc in loaded) {
          final ids = [userId, doc['id'] as String]..sort();
          final convId = ids.join('_');
          try {
            final lastMsgData = await _supabase
                .from('messages')
                .select('content, created_at, sender_id')
                .eq('conversation_id', convId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            if (lastMsgData != null) {
              final dt = DateTime.parse(lastMsgData['created_at']).toLocal();
              doc['lastMessage'] = lastMsgData['content'] as String;
              doc['lastMessageTime'] = '${dt.hour.toString().padLeft(2, '0')}:'
                  '${dt.minute.toString().padLeft(2, '0')}';
            }

            final unreadData = await _supabase
                .from('messages')
                .select('id')
                .eq('conversation_id', convId)
                .eq('receiver_id', userId)
                .eq('is_read', false);

            doc['unread'] = (unreadData as List).length;
          } catch (_) {}
        }
      }

      loaded.sort((a, b) {
        if (a['isMyCardiologist'] == true && b['isMyCardiologist'] != true)
          return -1;
        if (b['isMyCardiologist'] == true && a['isMyCardiologist'] != true)
          return 1;
        return 0;
      });

      if (mounted) {
        setState(() {
          _cardiologists = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading cardiologists: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _cardiologists;
    return _cardiologists
        .where((d) =>
            d['name']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            d['specialty']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Map<String, dynamic>> get _onlineCardiologists =>
      _cardiologists.where((d) => d['available'] == true).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bg = ThemeHelper.background(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPri = ThemeHelper.textPrimary(context);
    final textSec = ThemeHelper.textSecondary(context);
    final primary = ThemeHelper.primary;

    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final hasAlert = app.emergencyState != EmergencyState.none;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: surface,
            foregroundColor: textPri,
            elevation: 0,
            title: Text(l10n.t('messages'),
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: textPri)),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const EmergencyScreen(showBackButton: true),
                    ),
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.critical,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.critical.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.emergency_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(l10n.t('emergency'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: border)),
          ),
          body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primary),
                      const SizedBox(height: 12),
                      Text(l10n.t('loading_cardiologists'),
                          style: TextStyle(color: textSec)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (hasAlert)
                      _AlertBanner(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EmergencyScreen(
                                      showBackButton: true)))),
                    if (_myCardiologistLabel != null &&
                        _myCardiologistLabel!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin:
                            const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primary.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.star_rounded, color: primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                            '${l10n.t('my_cardiologist')} : $_myCardiologistLabel',
                            style: TextStyle(
                                fontSize: 13,
                                color: primary,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          )),
                        ]),
                      ),
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border)),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(color: textPri),
                          decoration: InputDecoration(
                            hintText: l10n.t('search_cardiologist_hint'),
                            hintStyle: TextStyle(color: textSec, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: textSec, size: 22),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        color: textSec, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    })
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    if (_onlineCardiologists.isNotEmpty)
                      SizedBox(
                        height: 88,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _onlineCardiologists.length,
                          itemBuilder: (context, i) {
                            final doc = _onlineCardiologists[i];
                            return _OnlineDoctor(
                              doc: doc,
                              primary: primary,
                              textPri: textPri,
                              textSec: textSec,
                              onTap: () => _openChat(context, doc),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Expanded(
                            child: Text(l10n.t('cardiologists'),
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: textPri),
                                overflow: TextOverflow.ellipsis)),
                        Text(
                            l10n
                                .t('available_docs_count')
                                .replaceAll('{count}', '${_filtered.length}'),
                            style: TextStyle(
                                fontSize: 13,
                                color: primary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: textSec),
                                  const SizedBox(height: 12),
                                  Text(l10n.t('no_cardiologist_found'),
                                      style: TextStyle(color: textSec)),
                                  const SizedBox(height: 8),
                                  TextButton(
                                      onPressed: _loadCardiologists,
                                      child: Text(l10n.t('retry'),
                                          style: TextStyle(color: primary))),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadCardiologists,
                              color: primary,
                              child: ListView.builder(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    16, 0, 16, 16),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final doc = _filtered[i];
                                  return _DoctorCard(
                                    doc: doc,
                                    primary: primary,
                                    textPri: textPri,
                                    textSec: textSec,
                                    surface: surface,
                                    border: border,
                                    onTap: () => _openChat(context, doc),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _openChat(BuildContext context, Map<String, dynamic> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ChatScreen(doctor: doc)),
    ).then((_) => _loadCardiologists());
  }
}

// ════════════════════════════════════════════════════
// Bannière alerte
// ════════════════════════════════════════════════════
class _AlertBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AlertBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.critical,
        child: Row(children: [
          const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(l10n.t('alert_active_press_to_see'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14))),
          const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 16),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Cardiologue en ligne — scroll horizontal
// ════════════════════════════════════════════════════
class _OnlineDoctor extends StatelessWidget {
  final Map<String, dynamic> doc;
  final Color primary, textPri, textSec;
  final VoidCallback onTap;

  const _OnlineDoctor({
    required this.doc,
    required this.primary,
    required this.textPri,
    required this.textSec,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMyDoc = doc['isMyCardiologist'] == true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsetsDirectional.only(end: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: isMyDoc
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2.5))
                    : null,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: primary.withOpacity(0.15),
                  child: Text(
                    (doc['full_name'] as String)[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: ThemeHelper.background(context), width: 2)),
                ),
              ),
              if (isMyDoc)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.amber, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.star, color: Colors.white, size: 10),
                  ),
                ),
            ]),
            const SizedBox(height: 5),
            Text(
              (doc['full_name'] as String).split(' ').first,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: textPri),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Carte cardiologue
// ════════════════════════════════════════════════════
class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final Color primary, textPri, textSec, surface, border;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.doc,
    required this.primary,
    required this.textPri,
    required this.textSec,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMyDoc = doc['isMyCardiologist'] == true;
    final hasUnread = (doc['unread'] as int) > 0;
    final lastTime = (doc['lastMessageTime'] as String).isNotEmpty
        ? doc['lastMessageTime'] as String
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMyDoc ? primary.withOpacity(0.5) : border,
            width: isMyDoc ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMyDoc)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, color: primary, size: 12),
                const SizedBox(width: 4),
                Text(l10n.t('my_cardiologist'),
                    style: TextStyle(
                        fontSize: 11,
                        color: primary,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: isMyDoc
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: primary.withOpacity(0.4), width: 2))
                    : null,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: primary.withOpacity(0.15),
                  child: Text(
                    (doc['full_name'] as String)[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primary),
                  ),
                ),
              ),
              if (doc['available'] == true)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: ThemeHelper.background(context),
                            width: 1.5)),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(doc['name'] as String,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPri),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(doc['specialty'] as String,
                      style: TextStyle(
                          fontSize: 11,
                          color: primary,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if ((doc['hospital'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(doc['hospital'] as String,
                        style: TextStyle(fontSize: 10, color: textSec),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(l10n.t('online_status'),
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600)),
                ),
                if (lastTime.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(lastTime,
                      style: TextStyle(fontSize: 10, color: textSec)),
                ],
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
                child: Text(
              doc['lastMessage'] as String,
              style: TextStyle(
                  fontSize: 12,
                  color: hasUnread ? textPri : textSec,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
            const SizedBox(width: 8),
            if (hasUnread)
              Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: primary, borderRadius: BorderRadius.circular(100)),
                child: Text('${doc['unread']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                child: Text(l10n.t('messages')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Écran de chat — messages réels + Realtime
// ════════════════════════════════════════════════════
class _ChatScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const _ChatScreen({required this.doctor});

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  late String _conversationId;
  late String _patientUid;
  late String _doctorUid;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _patientUid = _supabase.auth.currentUser!.id;
    _doctorUid = widget.doctor['id'] as String;
    final ids = [_patientUid, _doctorUid]..sort();
    _conversationId = ids.join('_');
    _loadHistory();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    if (_channel != null) _supabase.removeChannel(_channel!);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('messages')
          .select('id, sender_id, content, created_at, is_read')
          .eq('conversation_id', _conversationId)
          .order('created_at', ascending: true)
          .limit(100);

      final List<Map<String, dynamic>> msgs = (data as List).map((m) {
        final isMe = (m['sender_id'] as String) == _patientUid;
        final dt = DateTime.parse(m['created_at'] as String).toLocal();
        return {
          'id': m['id'],
          'text': m['content'],
          'isMe': isMe,
          'time': '${dt.hour.toString().padLeft(2, '0')}:'
              '${dt.minute.toString().padLeft(2, '0')}',
          'isRead': m['is_read'] ?? false,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
        });
      }

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', _conversationId)
          .eq('receiver_id', _patientUid)
          .eq('is_read', false);

      _scrollToBottom();
    } catch (e) {
      debugPrint('❌ Erreur historique: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('conv:$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId,
          ),
          callback: (payload) {
            final m = payload.newRecord;
            final isMe = (m['sender_id'] as String) == _patientUid;
            final dt = DateTime.parse(m['created_at'] as String).toLocal();
            final msg = {
              'id': m['id'],
              'text': m['content'],
              'isMe': isMe,
              'time': '${dt.hour.toString().padLeft(2, '0')}:'
                  '${dt.minute.toString().padLeft(2, '0')}',
              'isRead': m['is_read'] ?? false,
            };
            if (mounted) setState(() => _messages.add(msg));
            _scrollToBottom();
            if (!isMe) {
              _supabase
                  .from('messages')
                  .update({'is_read': true}).eq('id', m['id'] as String);
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgController.clear();
    try {
      await _supabase.from('messages').insert({
        'conversation_id': _conversationId,
        'sender_id': _patientUid,
        'receiver_id': _doctorUid,
        'content': text,
      });
    } catch (e) {
      debugPrint('❌ Erreur envoi: $e');
      if (mounted) _msgController.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bg = ThemeHelper.background(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPri = ThemeHelper.textPrimary(context);
    final textSec = ThemeHelper.textSecondary(context);
    final primary = ThemeHelper.primary;
    final isMyDoc = widget.doctor['isMyCardiologist'] == true;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textPri,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textPri),
            onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: primary.withOpacity(0.15),
              child: Text(
                (widget.doctor['full_name'] as String)[0].toUpperCase(),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: primary),
              ),
            ),
            if (isMyDoc)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                      color: Colors.amber, shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.white, size: 9),
                ),
              ),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Flexible(
                      child: Text(widget.doctor['name'] as String,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPri),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  if (isMyDoc) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(l10n.t('my_cardio'),
                          style: TextStyle(
                              fontSize: 9,
                              color: primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                Text('● ${l10n.t('online_status')}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF10B981))),
              ],
            ),
          ),
        ]),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: border)),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: primary))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 48, color: textSec),
                          const SizedBox(height: 12),
                          Text(l10n.t('start_conversation'),
                              style: TextStyle(color: textSec, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isMe = msg['isMe'] as bool;
                        final isRead = msg['isRead'] as bool;
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.72),
                            decoration: BoxDecoration(
                              color: isMe ? primary : surface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                              ),
                              border: isMe ? null : Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(msg['text'],
                                    style: TextStyle(
                                        color: isMe ? Colors.white : textPri,
                                        fontSize: 14,
                                        height: 1.4)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(msg['time'],
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white70
                                                : textSec)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        isRead
                                            ? Icons.done_all_rounded
                                            : Icons.done_rounded,
                                        size: 13,
                                        color: isRead
                                            ? Colors.white
                                            : Colors.white38,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: surface, border: Border(top: BorderSide(color: border))),
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: border)),
                  child: TextField(
                    controller: _msgController,
                    style: TextStyle(color: textPri),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: l10n.t('write_message'),
                      hintStyle: TextStyle(color: textSec, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sending ? null : _sendMessage,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: _sending ? primary.withOpacity(0.5) : primary,
                      shape: BoxShape.circle),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
