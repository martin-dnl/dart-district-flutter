import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/google_places_service.dart';
import '../../../core/network/nominatim_service.dart';
import '../widgets/opening_hours_input.dart';
import '../widgets/territory_confirmation_modal.dart';
import '../widgets/territory_not_found_modal.dart';

class ClubCreateScreen extends ConsumerStatefulWidget {
  const ClubCreateScreen({super.key});

  @override
  ConsumerState<ClubCreateScreen> createState() => _ClubCreateScreenState();
}

class _ClubCreateScreenState extends ConsumerState<ClubCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'France');
  final _dartBoardsController = TextEditingController();

  final NominatimService _nominatimService = NominatimService();

  bool _submitting = false;
  Timer? _autocompleteDebounce;
  bool _autocompleteLoading = false;
  List<PlaceSuggestion> _suggestions = const [];
  Map<String, dynamic> _openingHours = const <String, dynamic>{};

  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _autocompleteDebounce?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _dartBoardsController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _autocompleteDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _autocompleteLoading = false;
        _suggestions = const [];
      });
      return;
    }

    setState(() => _autocompleteLoading = true);
    _autocompleteDebounce = Timer(const Duration(milliseconds: 500), () async {
      final places = ref.read(googlePlacesServiceProvider);
      final suggestions = await places.autocomplete(query);
      if (!mounted) return;
      setState(() {
        _autocompleteLoading = false;
        _suggestions = suggestions;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final places = ref.read(googlePlacesServiceProvider);
    final details = await places.getPlaceDetails(suggestion.placeId);
    if (!mounted || details == null) {
      return;
    }

    setState(() {
      _nameController.text = details.name.isEmpty
          ? suggestion.mainText
          : details.name;
      _addressController.text = details.formattedAddress;
      _cityController.text = details.city ?? _cityController.text;
      _postalCodeController.text = details.postalCode ?? _postalCodeController.text;
      _countryController.text = details.country ?? _countryController.text;
      _openingHours = {
        for (final entry in details.openingHours.entries)
          entry.key: entry.value.toJson(),
      };
      _latitude = details.latitude;
      _longitude = details.longitude;
      _suggestions = const [];
      _autocompleteLoading = false;
    });
  }

  Future<Map<String, dynamic>?> _resolveTerritory() async {
    final api = ref.read(apiClientProvider);

    var lat = _latitude;
    var lng = _longitude;

    if (lat == null || lng == null) {
      final composedAddress = [
        _addressController.text.trim(),
        _postalCodeController.text.trim(),
        _cityController.text.trim(),
        _countryController.text.trim(),
      ].where((value) => value.isNotEmpty).join(', ');

      final fallback = await _nominatimService.searchCity(composedAddress);
      if (fallback.isNotEmpty) {
        lat = fallback.first.lat;
        lng = fallback.first.lng;
        _latitude = lat;
        _longitude = lng;
      }
    }

    if (lat == null || lng == null) {
      return null;
    }

    final response = await api.post<Map<String, dynamic>>(
      '/clubs/resolve-territory',
      data: {
        'latitude': lat,
        'longitude': lng,
      },
    );

    final payload = response.data ?? <String, dynamic>{};
    if (payload['success'] == true && payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }

    if ((payload['error'] ?? '').toString() == 'no_territory_found') {
      return null;
    }

    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);

      final territory = await _resolveTerritory();
      if (territory == null) {
        if (mounted) {
          await TerritoryNotFoundModal.show(context);
        }
        return;
      }

      if (!mounted) return;

      final confirmed = await TerritoryConfirmationModal.show(
        context,
        name: (territory['name'] ?? '').toString(),
        city: (territory['city'] ?? '').toString(),
        department: territory['department']?.toString(),
        region: territory['region']?.toString(),
      );

      if (!confirmed) {
        return;
      }

      final dartBoards = int.tryParse(_dartBoardsController.text.trim());
      await api.post<Map<String, dynamic>>(
        '/clubs',
        data: {
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          'city': _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          'postal_code': _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          'country': _countryController.text.trim().isEmpty
              ? 'France'
              : _countryController.text.trim(),
          'dart_boards_count': dartBoards,
          'opening_hours': _openingHours,
          'latitude': _latitude,
          'longitude': _longitude,
          'code_iris': territory['code_iris'],
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Club cree avec succes')));
      context.go(AppRoutes.club);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de creer le club.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Creer un club'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Nouveau club',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Configurez votre club et commencez la conquete de votre territoire.',
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradient,
                  border: Border.all(color: AppColors.stroke),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Nom du club'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        onChanged: _onNameChanged,
                        style: const TextStyle(color: AppColors.textPrimary),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 3) {
                            return 'Nom minimum: 3 caracteres';
                          }
                          return null;
                        },
                        decoration: _inputDecoration('Ex: Darts Rivals'),
                      ),
                      if (_autocompleteLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.stroke),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) => Divider(
                              color: AppColors.stroke.withValues(alpha: 0.7),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              return ListTile(
                                dense: true,
                                onTap: () => _selectSuggestion(suggestion),
                                title: Text(
                                  suggestion.mainText,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  suggestion.secondaryText,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 14),
                      _label('Adresse'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        minLines: 2,
                        maxLines: 3,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Adresse requise';
                          }
                          return null;
                        },
                        decoration: _inputDecoration('Ex: 12 rue de la Gare'),
                      ),
                      const SizedBox(height: 14),
                      _label('Ville'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cityController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Ville requise';
                          }
                          return null;
                        },
                        decoration: _inputDecoration('Ex: Nantes'),
                      ),
                      const SizedBox(height: 14),
                      _label('Code postal'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _postalCodeController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration('Ex: 44000'),
                      ),
                      const SizedBox(height: 14),
                      _label('Pays'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _countryController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration('Ex: France'),
                      ),
                      const SizedBox(height: 14),
                      _label('Nombre de cibles'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dartBoardsController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed < 1 || parsed > 100) {
                            return 'Valeur attendue: 1 a 100';
                          }
                          return null;
                        },
                        decoration: _inputDecoration('Ex: 8'),
                      ),
                      const SizedBox(height: 14),
                      _label('Horaires hebdomadaires'),
                      const SizedBox(height: 8),
                      OpeningHoursInput(
                        initialValue: _openingHours,
                        onChanged: (value) => _openingHours = value,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_business_rounded),
                  label: Text(
                    _submitting ? 'Creation en cours...' : 'Creer le club',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surface.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
