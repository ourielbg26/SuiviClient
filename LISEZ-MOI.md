# Suivi Client — projet Xcode prêt à l'emploi

## Ouvrir le projet

Double-clique sur **`SuiviClient.xcodeproj`** dans ce dossier. Xcode s'ouvre avec le
projet déjà configuré : cible iOS 17+, polices Playfair Display et Montserrat déjà
embarquées et déclarées (rien à installer).

## Lancer l'app

1. En haut de la fenêtre Xcode, choisis un simulateur d'iPhone (ex. "iPhone 15") à côté
   du bouton ▶.
2. Clique sur ▶ (ou `Cmd+R`).

Pour l'installer sur ton propre iPhone : branche-le, sélectionne-le dans la même liste,
puis dans l'onglet du projet **Signing & Capabilities**, choisis ton compte Apple
(gratuit) comme équipe. Xcode demandera de faire confiance à l'app sur l'iPhone au
premier lancement (Réglages → Général → VPN et gestion de l'appareil).

J'ai vérifié que le projet compile sans erreur (build en ligne de commande contre le
SDK iOS 17 Simulator).

## Ce qui est fait

Toutes les étapes du cahier des charges (`design_handoff_suivi_client/README.md`) :

- `Theme.swift` : toutes les couleurs, polices, rayons, ombres du document — aucun hex
  en dur dans les vues.
- Stockage en fichiers JSON (pas SwiftData — voir "Stockage et synchro entre iPhone"
  ci-dessous) + formatteurs fr_FR.
- Barre d'onglets flottante en verre (4 onglets), piles de navigation Accueil/Contacts.
- Accueil : les 4 listes par statut, tri du plus ancien, 5 par liste + "Afficher les N",
  badge Retard.
- Transactions : recherche + panneau de filtres (dont période personnalisée).
- Fiche transaction : hero, statuts cliquables + bouton de passage, détails, paiement +
  échéancier, note, photos, Modifier, Supprimer.
- Formulaire (création et modification) : champ à suggestions réutilisable avec
  "Enregistrer … dans la liste", multi-sélection réparations, provenance Stock/Commande,
  paiement en plusieurs fois, proposition d'enregistrer le contact.
- Stats : synthèse de période, donut par catégorie (Swift Charts), classement en colonnes.
- Contacts + fiche cliente avec historique et création pré-remplie.
- Paramètres : les 4 catalogues avec compteur d'utilisation.
- États vides partout ; l'app démarre **vide** en dehors du mode debug.

## Stockage et synchro entre iPhone

Il n'y a plus de base SwiftData : chaque cliente est un fichier JSON séparé (avec toutes
ses transactions dedans), plus un fichier pour les 4 catalogues. Toujours gardés **en
local** sur le téléphone (l'app marche sans réseau), et copiés sur **Google Drive** dès
que le réseau est là — synchronisés automatiquement au lancement de l'app, sans aucun
réglage à faire sur les iPhone. Les **photos vivent uniquement sur Drive** (pas de copie
locale une fois envoyées) ; si une photo est prise hors ligne, elle patiente sur le
téléphone jusqu'au prochain lancement avec réseau, puis part sur Drive et s'efface du
téléphone.

Ce lien Drive passe par un petit script (voir `google-apps-script/`) — **il reste à le
déployer** : suis `google-apps-script/LISEZ-MOI.md` et envoie-moi l'URL obtenue à la fin,
je la mets dans `SuiviClient/Support/DriveConfig.swift`. Tant que ce n'est pas fait,
l'app fonctionne normalement, juste en local uniquement sur chaque iPhone (pas d'écran de
connexion, rien de bloquant).

**Important, à savoir avant d'utiliser ça à deux :**
- Il n'y a **aucune fusion automatique**. Si les deux iPhone modifient la *même* fiche
  quasi en même temps, la dernière synchronisée l'emporte — l'autre modification est
  perdue côté partagé (une copie `.bak` reste récupérable à la main, en local et dans
  `Backups/` sur Drive), mais rien n'avertit sur le moment.
- La synchro se déclenche **au lancement de l'app** (pas en continu pendant qu'elle
  tourne) — pense à rouvrir l'app sur les deux iPhone après une série de modifications
  importantes.

## Données d'exemple

Un jeu de données de démo se charge automatiquement **uniquement en build Debug**
(`Support/SampleData.swift`, `DebugFlags.useSampleData`). Pour lancer l'app à vide même
en debug, passe cette constante à `false`. En build Release (App Store / TestFlight),
l'app démarre toujours vide.

## Libertés prises par rapport au HTML

- Champs natifs : `DatePicker`, `TextField`, clavier système, `PhotosPicker` pour les
  photos (au lieu des tuiles rayées du prototype).
- Le donut de Stats utilise Swift Charts (`SectorMark`) plutôt qu'un dégradé conique CSS.
- Le classement en colonnes est une vue SwiftUI faite main (barres + libellés), pas un
  graphique Charts, pour reproduire fidèlement le style du prototype (valeur au-dessus,
  nom + montant en dessous).

## Si un écran ne ressemble pas au prototype

Ouvre `design_handoff_suivi_client/Suivi Client v3.dc.html` dans un navigateur à côté et
compare — dis-moi ce qui cloche, je corrige.
