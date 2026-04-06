# Patch Note — Dart District v2.x.x

## 🚀 Sprint Territoires & Clubs (2026-04-06)

### ✅ Corrections UX / Partie
- Animation plus fluide sur la navbar (transition d'etat du bouton de navigation).
- Configuration de partie revue:
  - options disponibles: Inviter un ami, Scan, Local
  - suppression du bouton Territoire des options principales
  - ajout de switches dans Type de match: Classe et Territorial
  - renommage de "Vs Invite" en "Local"
- Le mode par defaut reste Local et le type de match est maintenant Amical par defaut.
- En mode Territorial, le mode Classe est force a actif.

### ✅ Correctif clubs
- Correction robuste du parsing de la reponse de recherche clubs (support payload enveloppe et payload brut).
- Ajout de logs explicites en cas d'echec de recherche clubs pour faciliter le diagnostic.

### ✅ Territorial Match Rules
- Le switch Territorial ouvre un scan QR de club et affiche le nom du club cible.
- Blocage du lancement de partie avec message clair si:
  - les deux joueurs appartiennent au meme club
  - aucun des deux joueurs n'appartient au club du territoire scanne

### ✅ Backend Match & ELO Territorial
- Ajout de nouveaux champs sur les matchs:
  - territory_club_id
  - territory_code_iris
- Ajout du traitement ELO en fin de match dans le service de matchs.
- Ajout de la logique de points territoriaux:
  - le delta ELO du gagnant est converti en points territoire-club
  - creation automatique de l'association club/territoire si absente

### ✅ Classement Clubs par Territoire
- Nouvelle table: club_territory_points
- Initialisation automatique de la relation club-territoire (points a 0) a la creation d'un club.
- Enrichissement de la modale territoire sur la carte avec un podium Top 3 des clubs.

### ✅ Tournois
- Ajout du flag is_ranked sur les tournois (DTO + entite + migration).
- Ajout des options Classe / Territorial dans l'ecran de creation de tournoi.
- Si Territorial est active sur un tournoi, Classe est force a actif.
- Controle d'acces creation tournoi lie a un club:
  - admin autorise
  - president du club autorise

### ✅ Auth / Donnees exposees
- Le JWT inclut maintenant le flag is_admin pour les controles backend.
- Les donnees contact exposent club_id pour les validations territoriales cote client.

### 🗄️ Migration SQL
- Nouvelle migration: backend/sql/021_territory_club_points_and_match_fields.sql
  - creation table club_territory_points
  - ajout des colonnes territory_club_id / territory_code_iris sur matches
  - ajout de la colonne is_ranked sur tournaments

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

## 🎮 Partie / Match live
- Ajout d'une animation de décrément du score lors de la validation d'un score non terminal (ralenti en fin d'animation)
- Ajout d'un bouton paramètres (roue crantée) en haut à droite sur l'écran de partie
- Nouvelle modale **Parametres partie** contenant :
  - mode de saisie du score
  - abandon de partie
  - retour arrière (undo)
  - partage spectateur
- Le partage spectateur affiche désormais un QR code de partie (avec bouton de copie de l'ID)
- Pour les modes X01 (301/501/701), ajout d'un composant TabBar en bas de l'écran :
  - onglet **Saisie score** (mode MANUAL)
  - onglet **Guideline** (recommandations checkout)

## 👥 Contacts
- Ajout d'une icône QR code dans la barre de recherche des contacts
- Le scan QR permet de retrouver un joueur et d'ouvrir directement son profil
- Le bouton **Ajouter** des résultats de recherche devient une icône `add_box_outlined` verte
- Les noms des joueurs sont cliquables vers le profil (résultats de recherche + demandes)

## ⚙️ Profil / Paramètres
- Ajout d'une section **Game options** dans les paramètres profil
- Nouveau paramètre **Score mode** (valeur actuelle : `MANUAL`)
- Ajout de séparateurs visuels (`Divider`) avant les actions de compte

## 🗄️ Backend
- Création d'une table `user_settings` pour stocker les préférences utilisateur par clé/valeur
- Ajout d'une migration SQL `018_user_settings.sql`
- Ajout des endpoints sécurisés :
  - `GET /users/me/settings?key=...`
  - `PATCH /users/me/settings` avec `{ key, value }`

## 🧩 Correctifs complémentaires
- Correction de l'upload avatar côté client : envoi multipart/form-data correctement géré
- Ajout d'un badge caméra en bas à droite de l'avatar sur le profil pour indiquer l'action de changement
