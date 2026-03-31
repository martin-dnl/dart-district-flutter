# 📘 Contexte Général – Application Mobile « Dart District »

Ce document complète **ai_project_guidelines.md** en décrivant le *contexte fonctionnel*, l’univers, les mécaniques de jeu et les écrans principaux de l’application mobile **Dart District**.

---

# 🎯 1. Présentation Générale

**Dart District** est une application mobile de fléchettes permettant de jouer :
- en ligne avec des amis  
- hors ligne  
- en club  
- en affrontement territorial entre clubs  

L’application repose sur :
- une architecture décrite dans `ai_project_guidelines.md`
- un backend NestJS + PostgreSQL
- une synchronisation temps réel (WebSockets)
- un système de statistiques avancées + ELO interne

---

# 🎯 2. Fonctionnalités Principales

## 2.1 Modes de jeux disponibles
L'application permet de jouer à plusieurs modes classiques et originaux :

### 🎯 Modes standards :
- **301 / 501 / 701**
- **Chasseur**
- **Cricket**

### ⚙️ Options supplémentaires :
- **Choix du type de finish** (double-out, single-out, master-out…)
- **Choix du nombre de legs par set**

---

## 2.2 Système de statistiques & ELO
- Chaque joueur possède une **fiche de statistiques détaillée** : précision, moyennes, hit-rates par segments…
- L’application inclut son **propre système d’ELO**, calculé après chaque match  
- Historique des matchs disponible  
- Stats accessibles même hors ligne (cache local avec resynchronisation)

---

## 2.3 Temps réel : partie + messagerie
- Les parties en ligne reposent sur un **système temps réel** (WebSockets).
- Chat intégré entre les joueurs.
- Mise à jour instantanée du score, des rounds, des actions.
- Système robuste de reconnexion automatique.

---

## 2.4 Mode hors ligne + resynchronisation
- L’utilisateur peut jouer entièrement hors ligne.
- À la reconnexion :
  - statistiques synchronisées
  - historiques des parties envoyés au serveur
  - mise à jour du classement global
- Le backend gère les conflits éventuels.

---

# 🏟️ 3. Clubs et « Guerre de Territoire »

## 3.1 Clubs
Les joueurs peuvent rejoindre des **clubs** (bars, salles de jeux, associations, etc.).

Chaque club possède :
- un classement interne  
- une liste de membres  
- ses zones conquises  
- son adresse  
- ses tournois en cours  

## 3.2 Guerre de territoire
Concept gamifié basé sur une **carte interactive** divisée en zones (quartiers / arrondissements / villes).

Chaque zone peut être :
- 🟩 **Disponible**
- 🟦 **Conquise par un club**
- 🟥 **En conflit**

### Conquête / Défense :
- Les membres d’un club peuvent **défier les membres d’un autre club** pour gagner ou défendre une zone.

## 3.3 Défi territorial via QR Code
Un QR Code est affiché à côté d'une cible de fléchettes réelle.  
Scénario :
1. Un joueur scanne le QR Code via l’app.
2. Cela déclenche un **défi en présentiel** contre un joueur rival.
3. Le vainqueur fait gagner ou perdre le territoire de la zone associée.

---

# 🔐 4. Authentification

## Méthodes de connexion :
- **Google Sign‑In**
- **Apple Sign‑In** (iOS uniquement)
- **Mode invité** (sans compte mais limité)

### Écrans de référence UI :
Les images suivantes servent aux IA pour générer les écrans correspondants :
- Connexion / Inscription : `./ref_ui/login.png`
- Abonnements éventuels : `subscription*.png`
- État non connecté : `./ref_ui/notlogged.png`

---

# 🗺️ 5. Pages Principales (Navigation en Bottom‑Menu)

L’application possède 5 pages principales accessibles en bas de l’écran.

## 5.1 Accueil
Référence UI : `./ref_ui/home.png`  
Affiche :
- résumé des stats du joueur  
- infos du club  
- infos de la guerre de territoire  
- parties en cours / récentes  
- conseils ou notifications utiles  

---

## 5.2 Carte
Référence UI :
- visuel principal : *à créer*  
- inspiration / classement : `./ref_ui/ranking.png`  

Affiche :
- carte interactive centrée sur la localisation du joueur  
- zones colorées : Disponible / Conquise / En conflit  
- icône du club dominant la zone  

---

## 5.3 Jouer
Référence UI : *à créer*  
Permet :
- sélectionner un mode de jeu (301 / 501 / Cricket…)  
- inviter un ami  
- jouer contre un invité  
- sélectionner les options de partie (finish, legs, set…)

---

## 5.4 Club
Référence UI : `./ref_ui/club.png`  

Affiche :
- statistiques du club  
- zones contrôlées  
- classement interne  
- membres du club  
- adresse et infos générales  
- tournois en cours  

---

## 5.5 Profil
Référence UI : `./ref_ui/profile*.png`  

Affiche :
- statistiques globales du joueur  
- progression ELO  
- historique des parties  
- badges / accomplissements  

---

# 🎮 6. Interface de Match en Direct

Référence UI : `./ref_ui/match_live`  

Contient :
- scoreboard dynamique  
- détails des rounds  
- jauges et inputs pour les tirs  
- affichage temps réel des actions adverses  
- chat / signalling du match  

---

# 📦 7. Références UI à disposition

Les dossiers suivants contiennent les images UI que les IA doivent utiliser pour générer les pages :

``