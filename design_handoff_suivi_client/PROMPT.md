# À coller dans Claude Code (VS Code)

## Avant de commencer

1. Xcode → Create New Project → iOS → App
   Nom `SuiviClient` · Interface **SwiftUI** · Language Swift · Storage **SwiftData**
2. Ferme Xcode, ouvre le dossier du projet dans VS Code
3. Copie ce dossier de handoff dedans (`SuiviClient/design_handoff_suivi_client/`)
4. Lance Claude Code dans ce dossier

## Le prompt

---

Tu vas implémenter une app iOS SwiftUI à partir d'une spec de design.

Lis d'abord `design_handoff_suivi_client/README.md` en entier : c'est la source de vérité
(couleurs exactes, typographie, rayons, ombres, modèle de données, règles de calcul,
navigation, et chaque écran décrit champ par champ). Le fichier
`design_handoff_suivi_client/Suivi Client v3.dc.html` est le prototype HTML de référence —
un design, pas du code à porter : ne copie pas son JS, recrée les écrans en SwiftUI natif.

Contexte : app pour une seule utilisatrice, vendeuse et réparatrice de perruques. Elle
enregistre des prestations (vente, réparation, couleur, lavage, produit), suit l'état de chaque
perruque et les paiements (dont les paiements en plusieurs fois), consulte des statistiques
et un carnet de contacts.

Contraintes techniques :
- iOS 17+, SwiftUI, iPhone portrait uniquement, français, aucun réseau
- Persistance locale SwiftData (`Transaction`, `Contact` — modèle dans le README)
- Montants `280 €` (fr_FR, sans décimale) ; dates courtes `24 août`
- Polices Playfair Display (titres, noms, gros montants) + Montserrat (le reste), embarquées
- Un `Theme.swift` qui centralise toutes les couleurs, polices, rayons et ombres du README —
  aucun hex en dur dans les vues
- Icônes : SF Symbols (liste dans le README)
- La barre d'onglets est une **capsule flottante translucide** (material + flou), pas une
  `TabView` standard ; chaque écran garde 96 pt de padding bas

Ordre de travail, en t'arrêtant à chaque étape pour que je valide :
1. `Theme.swift` + modèles SwiftData + formatteurs + jeu de données d'exemple (derrière un flag de debug)
2. Coquille de navigation : barre flottante 4 onglets (Accueil · Stats · Contacts · Paramètres)
3. Accueil : les quatre listes par statut, tri du plus ancien, 5 par liste + « Afficher les N »,
   badge Retard sur les échéances dépassées
4. Transactions : recherche + panneau de filtres (dont période personnalisée)
5. Fiche transaction : hero, bloc Suivi (4 statuts cliquables + bouton de passage avec les
   règles de dates), détails, paiement + échéancier, note, photos, Modifier, Supprimer
6. Formulaire (création ET modification) : champs par catégorie, le composant « champ à
   suggestions » réutilisable (avec « Enregistrer … dans la liste »), multi-sélection des
   réparations, provenance Stock/Commande pour la vente, paiement en plusieurs fois,
   proposition d'enregistrer le contact
7. Stats : synthèse de période (dont Période… avec deux dates), donut par catégorie,
   classement en colonnes
8. Contacts + fiche cliente (totaux, historique, nouvelle transaction pré-remplie)
9. Paramètres : les quatre catalogues (réparations, couleurs, types couleur, produits)
10. États vides propres partout, et vérification que l'app démarre sans données d'exemple

Respecte les valeurs du README au point près. Si quelque chose manque dans la spec,
pose-moi la question au lieu d'improviser.

---

## Ensuite

Quand une étape te convient, dis « étape suivante ».
Si un écran ne ressemble pas au prototype, ouvre le HTML à côté et compare.
