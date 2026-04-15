import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/config/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../controller/club_controller.dart';
import '../controller/club_search_controller.dart';
import '../models/club_model.dart';
import '../widgets/club_search_tile.dart';

class ClubScreen extends ConsumerWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ClubDiscoveryScreen();
  }
}

class _ClubDiscoveryScreen extends ConsumerStatefulWidget {
  const _ClubDiscoveryScreen();

  @override
  ConsumerState<_ClubDiscoveryScreen> createState() =>
      _ClubDiscoveryScreenState();
}

class _ClubDiscoveryScreenState extends ConsumerState<_ClubDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLocating = false;
  bool _usingNearbyFilter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialNearbyClubs();
    });
  }

  Future<void> _loadInitialNearbyClubs() async {
    final clubSearchNotifier = ref.read(clubSearchControllerProvider.notifier);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await clubSearchNotifier.loadInitial();
        if (mounted) {
          setState(() => _usingNearbyFilter = false);
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await clubSearchNotifier.loadInitial();
        if (mounted) {
          setState(() => _usingNearbyFilter = false);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await clubSearchNotifier.searchNearby(
        position.latitude,
        position.longitude,
        limit: 10,
      );
      if (mounted) {
        setState(() => _usingNearbyFilter = true);
      }
    } catch (_) {
      await clubSearchNotifier.loadInitial();
      if (mounted) {
        setState(() => _usingNearbyFilter = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchNearby() async {
    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await ref
          .read(clubSearchControllerProvider.notifier)
          .searchNearby(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _usingNearbyFilter = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_isLocating) {
      return;
    }

    final query = _searchController.text.trim();
    if (_usingNearbyFilter) {
      await _searchNearby();
      return;
    }

    if (query.isNotEmpty) {
      await ref
          .read(clubSearchControllerProvider.notifier)
          .searchByTextNow(query);
      return;
    }

    await ref.read(clubSearchControllerProvider.notifier).loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(clubSearchControllerProvider);
    final clubState = ref.watch(clubControllerProvider);
    final myClub = clubState.club;
    final currentUser = ref.watch(currentUserProvider);
    final canCreateClub = currentUser?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trouver un club',
                style: GoogleFonts.rajdhani(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (myClub != null) ...[
                const SizedBox(height: 12),
                _MyClubTile(club: myClub),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _usingNearbyFilter = false);
                        ref
                            .read(clubSearchControllerProvider.notifier)
                            .searchByText(value);
                      },
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un club par nom ou ville...',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.card.withValues(alpha: 0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.stroke),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.stroke),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: IconButton(
                      onPressed: _isLocating ? null : _searchNearby,
                      icon: _isLocating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.primary,
                            ),
                      tooltip: 'Clubs à proximité',
                    ),
                  ),
                ],
              ),
              if (canCreateClub) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.clubCreate),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer un club'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _onRefresh,
                  child: _ClubSearchResults(
                    state: searchState,
                    canCreateClub: canCreateClub,
                    onCreateClub: () => context.push(AppRoutes.clubCreate),
                    onReset: () {
                      _searchController.clear();
                      setState(() => _usingNearbyFilter = false);
                      ref.read(clubSearchControllerProvider.notifier).clear();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyClubTile extends StatelessWidget {
  const _MyClubTile({required this.club});

  final ClubModel club;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () =>
          context.push(AppRoutes.clubDetail.replaceFirst(':id', club.id)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mon club',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  club.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _ClubSearchResults extends StatelessWidget {
  const _ClubSearchResults({
    required this.state,
    required this.onReset,
    required this.canCreateClub,
    required this.onCreateClub,
  });

  final ClubSearchState state;
  final VoidCallback onReset;
  final bool canCreateClub;
  final VoidCallback onCreateClub;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }

    if (state.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              state.error!,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (state.results.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.travel_explore_rounded,
                  size: 56,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Recherchez un club',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Réinitialiser'),
                ),
                if (canCreateClub) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: onCreateClub,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer un club'),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: state.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final club = state.results[index];
        return ClubSearchTile(club: club);
      },
    );
  }
}
