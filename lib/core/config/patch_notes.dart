class PatchNote {
  const PatchNote({
    required this.version,
    required this.buildNumber,
    required this.date,
    required this.highlights,
    this.fixes = const [],
  });

  final String version;
  final int buildNumber;
  final String date;
  final List<String> highlights;
  final List<String> fixes;
}

const List<PatchNote> patchNotes = [
  PatchNote(
    version: '1.0.1',
    buildNumber: 2,
    date: '2026-04-02',
    highlights: [
      'Conditions d\'utilisation a l\'inscription',
      'Profil public des joueurs',
      'Club partenaire sur les tournois',
      'Patch notes integrees',
    ],
    fixes: [
      'Correction upload photo de profil sur Android',
      'Amelioration securite du repository',
    ],
  ),
];
