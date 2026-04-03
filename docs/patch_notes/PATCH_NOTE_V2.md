# Patch Note — Dart District v2.x.x

## 🎯 Nouvelles fonctionnalités

### Mode Invité amélioré
- Les utilisateurs peuvent explorer l'application en tant qu'invité sans création de compte en base de données
- L'invité accède aux clubs, tournois et à la carte en consultation
- Les fonctionnalités sociales et compétitives sont réservées aux joueurs inscrits :
  - Configuration de match limitée au mode "VS Invité"
  - Inscription aux tournois et création de tournois désactivées
  - Ajout de contacts désactivé
  - Rejoindre un club désactivé
  - QR code et suppression de compte masqués

### Localisation des clubs sur la carte
- **Association territoriale** : chaque club peut maintenant stocker un `code_iris` et être rattaché à une zone IRIS
- **Carte filtrée** : la carte ne rend désormais que les zones IRIS ayant au moins un club rattaché
- **Info territoire** : cliquer sur une zone affiche les informations du territoire (nom, code IRIS, statut)
- **Marqueurs de clubs** : les clubs apparaissent avec une icône de cible. Un clic ouvre une modale avec le nom du club et un lien vers son détail

## 🔧 Correctifs

### Inscription SSO corrigée
- Les nouveaux utilisateurs SSO Google sont redirigés vers le processus d'inscription complet (pseudo, niveau, conditions d'utilisation)
- Les utilisateurs tentant de se connecter via SSO sans compte existant sont automatiquement redirigés vers l'inscription — aucune erreur affichée
- Si l'inscription SSO a été interrompue, le prochain login reprend automatiquement le parcours d'onboarding

### Page Conditions d'utilisation scrollable
- La page des conditions d'utilisation (étape 2 de l'inscription) est désormais entièrement scrollable
- Le bouton "Commencer" est accessible sur tous les formats d'écran, y compris les petits appareils

## 📋 Notes techniques
- Migration SQL `017_clubs_code_iris.sql` : ajout du champ `code_iris` sur la table `clubs`
- Le token Guest est éphémère (JWT sans refresh, non persisté en BDD)
- Nouveau endpoint `GET /clubs/map` pour les marqueurs de carte
- Nouveau endpoint `GET /territories/clubs/zones` pour le filtrage des tiles
