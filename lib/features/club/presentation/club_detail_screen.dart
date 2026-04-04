import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/network/api_providers.dart';
import '../models/club_model.dart';
import '../widgets/member_list_tile.dart';

class ClubDetailScreen extends ConsumerStatefulWidget {
  const ClubDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  ClubModel? _club;
  List<Map<String, dynamic>> _tournaments = const [];

  List<Map<String, dynamic>> _extractMapList(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }

    if (payload is Map) {
      final mapped = payload.map((k, v) => MapEntry(k.toString(), v));
      final data = mapped['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
      if (data is Map) {
        final items = data['items'];
        if (items is List) {
          return items
              .whereType<Map>()
              .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
              .toList(growable: false);
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final clubResponse = await api.get<Map<String, dynamic>>('/clubs/${widget.id}');
      final clubData =
          (clubResponse.data?['data'] as Map<String, dynamic>?) ??
          clubResponse.data ??
          <String, dynamic>{};

      List<Map<String, dynamic>> tournamentsData = const [];
      try {
        final tournamentsResponse = await api.get<dynamic>(
          '/tournaments',
          queryParameters: {'club_id': widget.id},
        );
        tournamentsData = _extractMapList(tournamentsResponse.data)
            .where((item) {
              final status = (item['status'] ?? '').toString().toLowerCase();
              return status != 'completed' && status != 'cancelled';
            })
            .toList(growable: false);
      } catch (_) {
        tournamentsData = const [];
      }

      if (!mounted) return;
      setState(() {
        _club = ClubModel.fromApi(clubData);
        _tournaments = tournamentsData;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le club';
        _loading = false;
      });
    }
  }

  Future<void> _openNavigation() async {
    final address = [
      _club?.address,
      _club?.postalCode,
      _club?.city,
      _club?.country,
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');

    if (address.isEmpty) {
      return;
    }

    final encodedAddress = Uri.encodeComponent(address);
    final geoUri = Uri.parse('geo:0,0?q=$encodedAddress');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }

    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
    );
    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
  }

  List<ClubMember> _sortedMembers() {
    final members = [...?_club?.members];
    int rankForRole(String role) {
      return switch (role.toLowerCase()) {
        'president' => 0,
        'captain' => 1,
        _ => 2,
      };
    }

    members.sort((a, b) {
      final roleCompare = rankForRole(a.role).compareTo(rankForRole(b.role));
      if (roleCompare != 0) {
        return roleCompare;
      }
      return b.elo.compareTo(a.elo);
    });
    return members;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _club == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Club')),
        body: Center(
          child: Text(
            _error ?? 'Erreur inattendue',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }

    final club = _club!;
    final address = [
      club.address,
      club.postalCode,
      club.city,
      club.country,
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');
    final members = _sortedMembers();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Club')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (address.isNotEmpty)
                  GestureDetector(
                    onTap: _openNavigation,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        address,
                        style: GoogleFonts.manrope(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _chip(Icons.track_changes, '${club.dartBoardsCount} cibles'),
                    _chip(Icons.emoji_events, 'Rang #${club.rank}'),
                    _chip(Icons.map, '${club.zonesControlled} zones'),
                    _chip(Icons.people_alt, '${club.memberCount} membres'),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Tournois en cours'),
              Tab(text: 'Membres'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _tournaments.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun tournoi en cours',
                          style: GoogleFonts.manrope(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        itemCount: _tournaments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final tournament = _tournaments[index];
                          final name = (tournament['name'] ?? 'Tournoi').toString();
                          final mode = (tournament['mode'] ?? tournament['format'] ?? '-').toString();
                          final status = (tournament['status'] ?? '-').toString();
                          final participants =
                              (tournament['participants_count'] as num?)?.toInt() ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.stroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mode: $mode | Statut: $status | Participants: $participants',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                members.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun membre',
                          style: GoogleFonts.manrope(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        itemCount: members.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return MemberListTile(
                            member: members[index],
                            rank: index + 1,
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
