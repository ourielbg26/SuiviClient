# Handoff — Suivi Client (app iOS, SwiftUI)

## 1. Le produit

App mobile pour **une seule utilisatrice** : une vendeuse / réparatrice de perruques.
Elle enregistre chaque prestation, suit où en est chaque perruque, ce qui est payé ou non,
consulte des statistiques et un carnet de contacts. Aucun réseau, aucun compte,
tout est local sur le téléphone.

Cible : **iOS 17+, SwiftUI, iPhone portrait uniquement, français**.

## 2. La référence de design

`Suivi Client v3.dc.html` est le **prototype de référence** : ouvre-le dans un navigateur
(le cadre 390 × 812 = un iPhone) et navigue dedans, tout est cliquable.
C'est un design, **pas du code à porter** : ne reprends pas son JS, recrée les écrans en
SwiftUI natif en respectant au point près les valeurs de ce document.

`support.js` doit rester à côté du HTML pour que le prototype s'ouvre.

**Fidélité attendue : haute.** Couleurs, typo, rayons, espacements et états sont définitifs.
Libertés admises : remplacer les contrôles HTML par leurs équivalents natifs (champs,
`DatePicker`, appareil photo), et suivre les conventions iOS pour le retour arrière et le clavier.

---

## 3. Design tokens

### Couleurs — rôles
| Rôle | Hex |
| --- | --- |
| Fond de l'app | `#FAF7F5` |
| Carte / fiche | `#FFFFFF` |
| Fond secondaire (tuiles, panneaux) | `#F7EDEF` |
| Fond des onglets / segmenté | `#F1E6E8` |
| Survol / pressé sur fond secondaire | `#EFE0E4` |
| Séparateur de ligne | `#F2E7E9` |
| Bordure | `#E8DADA` |
| Bordure pointillée (emplacement photo) | `#DFC9D2` |
| Texte principal | `#3A2E2B` |
| Texte secondaire / méta | `#8B7D7A` |
| Texte de chip inactive | `#6E5F5C` |
| Bouton principal | `#B88AA2` (pressé `#A77791`) |
| Bouton secondaire / teinte accent | `#F3E3EA` (pressé `#DCB6C8`) |
| Texte sur teinte accent | `#8A5F79` |
| Onglet actif (pastille + texte) | `#F3E3EA` / `#8A5F79` |
| Bouton désactivé | fond `#EBDDE3`, texte `#8B7D7A` |
| Rayures des emplacements photo | `#EFE2E5` / `#FAF5F6` |

### Couleurs — statut du travail
| Statut | Point | Fond de pastille | Texte |
| --- | --- | --- | --- |
| En cours | `#F0B77E` | `#FDEFE0` | `#A9702F` |
| Prêt à rendre | `#A7C9B4` | `#E7F1EB` | `#4F7E66` |
| Rendu | `#D9D9D9` | `#EFEFEF` | `#6B6B6B` |
| Retour | `#D67B7B` | `#F7E3E3` | `#A85252` |

### Couleurs — paiement
| État | Fond | Texte |
| --- | --- | --- |
| Payé | `#E4F0EA` | `#3F7A5F` |
| En cours de paiement (acompte) | `#FAF1DE` | `#8A6B24` |
| Impayé | `#F7E3E3` | `#A85252` |
| Alerte retard (badge plein) | `#D67B7B` sur blanc |

### Couleurs — catégories
| Catégorie | Trait / barre | Fond | Texte |
| --- | --- | --- | --- |
| Vente | `#C79BC8` | `#F3E6F3` | `#7E5480` |
| Réparation | `#E1A487` | `#FAEAE2` | `#9C5F44` |
| Couleur | `#C89CB8` | `#F5E7EF` | `#8A5F79` |
| Lavage | `#9CC9E8` | `#E7F1F9` | `#3F6B87` |
| Produit | `#B9A7D9` | `#EEE9F7` | `#5F5288` |

### Typographie
Deux familles, à embarquer (Google Fonts) :
- **Playfair Display** (600/700) — noms de clientes, titres d'écran, gros montants
- **Montserrat** (400/500/600) — tout le reste

| Usage | Taille / poids | Famille | Letter-spacing |
| --- | --- | --- | --- |
| Gros chiffre (stats) | 44 / 700 | Playfair | −0.035em |
| Montant hero (fiche) | 38 / 700 | Playfair | −0.035em |
| Titre d'écran | 20–24 / 700 | Playfair | −0.02em |
| Nom de cliente (fiche) | 22–26 / 700 | Playfair | −0.02em |
| Titre de section | 15–16 / 600 | Montserrat | — |
| Nom dans une liste | 15 / 600 | Montserrat | — |
| Montant dans une liste | 15 / 600 | Montserrat | — |
| Corps, note | 14 / 400, interligne 1.55 | Montserrat | — |
| Valeur clé/valeur | 14 / 600 | Montserrat | — |
| Libellé de champ | 12 / 500 | Montserrat | — |
| Sous-titre de ligne, méta | 11–12 / 400–500 | Montserrat | — |
| Pastille (statut, paiement) | 10 / 500 | Montserrat | — |
| Libellé d'onglet | 10 / 600 | Montserrat | — |

### Espacements, rayons, ombres
Échelle : 2 · 4 · 6 · 8 · 10 · 12 · 14 · 16 · 18 · 20 · 22.
Marge horizontale de contenu : **16**. Padding de carte : **18–22**. Gap entre cartes : **12**.
Padding bas des écrans : **96** (la barre d'onglets flotte au-dessus).

| Élément | Rayon |
| --- | --- |
| Carte | 24 (26 pour le hero et la carte de stats) |
| Bouton pleine largeur | 18 |
| Champ, tuile interne | 14–16 |
| Emplacement photo | 18 |
| Bouton retour 36×36 | 12 |
| Vignette 42×42 dans une liste | 14 |
| Avatar contact | cercle |
| Pastille, chip, segmenté | capsule |
| Barre d'onglets flottante | 30 |

Ombres : carte `0 1px 2px rgba(58,46,43,.06)` · bouton principal `0 8px 20px rgba(184,138,162,.26)` ·
carte de stats `0 10px 26px rgba(184,138,162,.30)` · segment actif `0 1px 3px rgba(58,46,43,.14)`.
(En SwiftUI, `radius` ≈ blur CSS / 2.)

---

## 4. Modèle de données

```swift
enum Category: String, CaseIterable, Codable {
    case vente = "Vente", reparation = "Réparation", couleur = "Couleur",
         lavage = "Lavage", produit = "Produit"
}
enum WorkStatus: String, CaseIterable, Codable {
    case enCours = "En cours", pret = "Prêt", rendu = "Rendu", retour = "Retour"
}
enum PayMethod: String, CaseIterable, Codable {
    case especes = "Espèces", carte = "Carte", cheque = "Chèque"
}
enum Origine: String, Codable { case stock = "Stock", commande = "Commande" }

struct Installments: Codable {          // paiement en plusieurs fois
    var paid: Decimal                   // déjà versé
    var due: Date                       // prochaine échéance
    var method: PayMethod               // espèces ou chèque uniquement
}

struct Transaction: Identifiable, Codable {
    var id: UUID
    var ref: String                     // "T-042"
    var clientName: String              // nom ET prénom dans un seul champ
    var phone: String
    var category: Category
    var item: String                    // libellé calculé (voir plus bas)
    var origine: Origine?               // Vente uniquement
    var price: Decimal
    var isPaid: Bool
    var method: PayMethod               // renseigné seulement si isPaid
    var plan: Installments?             // renseigné si paiement échelonné
    var status: WorkStatus
    var dropDate: Date                  // dépôt
    var pickupDate: Date?               // rendu
    var returnDate: Date?               // retour reçu
    var pickup2Date: Date?              // récupéré après retour
    var note: String
    var photos: [Data]                  // avant (réparation, couleur) / après (vente)
}

struct Contact: Identifiable, Codable {  // cliente sans transaction
    var id: UUID
    var name: String
    var phone: String
}
```

### Libellé `item` selon la catégorie
- **Vente** : `"<texture> <longueur> · <couleur> · Bonnet <taille>"`, + `" · Commande"` si provenance = Commande
- **Réparation** : les réparations choisies jointes par `" + "`
- **Couleur** : `"<type de coloration> · <couleur>"`
- **Lavage** : `"Lavage seul"` ou `"Lavage + coiffage · <finition>"`
- **Produit** : le produit choisi

### Règles de calcul
- Montants : sans décimale, séparateur de milliers = espace, suffixe `€` (`280 €`, `17 000 €`) — `NumberFormatter` locale `fr_FR`.
- Dates courtes : `24 août` (`d MMM`, locale `fr_FR`).
- Âge d'une fiche = jours entre dépôt et aujourd'hui ; au-delà de **14 jours** le texte passe en `#A85252`.
- Encaissé d'une période = somme des fiches payées + les acomptes déjà versés des fiches échelonnées.
- En attente = total facturé − encaissé.
- Retard d'échéance : `plan.due < aujourd'hui`.

---

## 5. Navigation

**Barre flottante en « liquid glass »**, pas une `TabView` standard : capsule posée au-dessus
du contenu, 14 pt des bords gauche/droit et du bas, rayon 30, padding 7/8, fond translucide
clair (~82 %) avec flou — en SwiftUI `.background(.regularMaterial, in: Capsule())`
(ou `.glassEffect()` sur iOS 26+), liseré blanc en haut, ombre `0 12px 30px rgba(58,46,43,.16)`.
Chaque écran garde 96 pt de padding bas.

Quatre onglets, icône dans une capsule 34×26 (active : fond `#F3E3EA`, icône et libellé `#8A5F79` ;
inactive : transparent, `#8B7D7A`) :

1. **Accueil** (maison) — pile : Accueil → Transactions → Fiche → Formulaire
2. **Stats** (barres)
3. **Contacts** (personne) — pile : Contacts → Fiche cliente → Nouvelle cliente
4. **Paramètres** (curseurs)

La fiche transaction est aussi atteignable depuis l'historique d'une cliente : le retour doit
revenir à l'écran d'origine.

---

## 6. Écrans

### 6.1 Accueil — quatre listes par statut
Titre « Atelier » (24/700 Playfair) + bouton capsule vert-rose « + Nouvelle fiche »
(fond `#B88AA2`, texte blanc, 12/600).

Quatre sections, chacune : un point de couleur + un titre 16/600 + le compte à droite, puis une
carte blanche de lignes. **Chaque liste n'affiche que 5 entrées** ; au-delà, un bouton
« Afficher les N » en bas de la carte (fond `#F7EDEF`, texte `#A77791`) qui déplie tout
(« Réduire » ensuite). Liste vide : une phrase grise dans la carte.

| Section | Point | Contenu | Tri | Sous-titre de ligne |
| --- | --- | --- | --- | --- |
| En cours | `#F0B77E` | statut En cours | **la plus ancienne en premier** | « Déposé le 24 août · 23 j » |
| Prêt à rendre | `#A7C9B4` | statut Prêt + Retour | la plus ancienne en premier | « Prêt · déposé le … » ou « Retour reçu le … » |
| Non payé | `#D67B7B` | Rendu, impayé, sans échéancier | la plus ancienne en premier | « Rendu le … » |
| En cours de paiement | `#D6B76E` | échéancier en cours (espèces ou chèque) | la plus ancienne en premier | « Reste 150 € · espèces · 5 sept. » + badge **Retard** si échéance dépassée |

Ligne : vignette 42×42 (rayon 14) aux initiales, nom, libellé, sous-titre coloré, montant à droite.
**Couleur de la vignette** = état : En cours → `#FDEFE0`/`#A9702F` · Prêt → `#E7F1EB`/`#4F7E66` ·
Retour → `#F7E3E3`/`#A85252` · Rendu impayé → **plein `#D67B7B`, texte blanc** · Rendu payé → `#E4F0EA`/`#3F7A5F`.

En bas : bouton bordé « Toutes les transactions » + le total.

### 6.2 Transactions (liste complète)
Recherche (nom, libellé, note) + bouton « Filtrer » (devient « Fermer », plein `#B88AA2` quand ouvert).
Panneau de filtres : chips capsules (active = `#B88AA2` / blanc ; inactive = `#FAF7F5` / `#6E5F5C` / bordure) —
**Paiement** (Tous, Payé, Impayé) · **Statut** (Tous + les 4) · **Catégorie** (Tous + les 5) ·
**Période** (Tout, Cette semaine, Ce mois, **3 derniers mois**, **Période…** → deux `DatePicker` Du / Au).
Lien « Réinitialiser ». Ligne de résultat : « N résultats » + la somme.
Lignes : vignette, nom, libellé, deux pastilles (statut + paiement), montant, date.

### 6.3 Fiche transaction
En-tête : retour, « Fiche T-042 », et un bouton capsule **Modifier** à droite.

- **Hero** (rayon 26) : fond selon l'état — En cours `#FDEFE0` / Prêt `#E7F1EB` / payé `#E4F0EA` /
  impayé `#F7E3E3`. Catégorie en 12/500, nom en 26/700 Playfair, libellé en 13/500,
  montant 38/700 Playfair, et deux capsules blanches translucides (paiement, statut).
- **Suivi** : les **quatre statuts en chips cliquables** (le statut actif est plein, de la couleur
  du statut) — c'est la deuxième façon de changer l'état — plus un bouton
  « Passer en « … » » qui fait tourner En cours → Prêt → Rendu → Retour → En cours.
  Règles de dates : passage à **Rendu** → remplit « Rendu le » avec aujourd'hui (et, si la fiche
  revient d'un retour, remplit « Récupéré après retour ») ; passage à **Retour** → remplit
  « Retour le » avec aujourd'hui et vide « Récupéré après retour ».
- **Détails** (clé / valeur) : Détail, **Provenance** (Vente : Stock ou Commande — « Commande » en `#A9702F`),
  Déposé le, Rendu le, Retour le, Récupéré (2ᵉ fois) — les trois dernières seulement si renseignées —, Référence.
- **Paiement** : l'état à droite en couleur (« Payé · Carte », « Échelonné · chèque », « Pas encore payé »).
  Si échéancier : un bloc Déjà versé / Reste à payer / Prochaine échéance —
  fond `#F7EDEF`, ou `#F7E3E3` + texte `#8F4444` si en retard (mention « · en retard »).
  Si impayé : bouton « Marquer comme payé ».
- **Note** : le texte, ou « Aucune note pour cette fiche. » en gris, + lien « Voir la fiche de <prénom> → ».
- **Photos** (réparation, couleur, vente) : titre « Photo avant » ou « Photos après », les photos
  existantes en 4:5, et toujours une tuile pointillée « + Avant / + Après » pour en ajouter.
- **Supprimer la fiche** : bouton bordé `#EBC9C9` / texte `#A85252`, puis confirmation dans un
  bloc `#F7E3E3` (Supprimer plein `#D67B7B` / Annuler).

### 6.4 Formulaire (nouvelle fiche ET modification)
Même écran ; le titre et le bouton changent (« Nouvelle fiche » / « Modifier la fiche »).

1. **Cliente** : un seul champ « Nom et prénom ». En tapant, suggestions des clientes existantes
   (avatar + nom + téléphone) qui remplissent nom et téléphone. Puis « Téléphone ».
   Si le nom saisi n'est **pas** un contact connu, un encart `#FDEFE0` apparaît :
   « <nom> sera ajoutée aux contacts. » avec un bouton **Oui / Non** — c'est le choix
   d'enregistrer ou pas le contact (par défaut Oui).
2. **Catégorie** d'abord (5 chips). Elle commande la suite :

| Catégorie | Champs |
| --- | --- |
| **Vente** | Couleur (liste) · **Provenance : Stock / Commande** · Taille du bonnet S/M/L/XL · Texture Raide/Ondulé/Bouclé/Crépu · Longueur 30-35/35-40/40-45/45-50/50+ (cm) · Note · **plusieurs photos après** |
| **Réparation** | Réparations **multi-sélection** depuis la liste (chips retirables) · Note · photo avant |
| **Couleur** | Type de coloration (liste : racine, balayage, ombré…) · Couleur (liste) · Note · photo avant |
| **Lavage** | Lavage seul / Lavage + coiffage ; si coiffage → Raide / Wavy / Cranté. Pas de note |
| **Produit** | Le produit (liste) uniquement |

3. **Champ « liste »** (le motif à reproduire partout) : un champ texte normal ; à la mise au
   point, un panneau de suggestions s'ouvre sous le champ avec les entrées enregistrées
   (point de couleur + nom + nombre d'utilisations), filtrées par ce qui est tapé.
   Si ce qui est tapé n'existe pas, une entrée verte-rose en bas du panneau :
   « Enregistrer « … » dans la liste » — qui l'ajoute au catalogue et la sélectionne.
   En multi-sélection, les entrées choisies s'affichent en chips retirables au-dessus du champ.
4. **Prix** et **Date de dépôt** côte à côte.
5. **Statut du travail** : 4 chips. Selon le statut, un bloc de dates apparaît
   (Rendu le / Retour reçu le / Récupéré après retour) **modifiables à la main**, plus le lien
   « Annuler le retour et effacer la date » qui vide le retour et repasse en Rendu.
6. **Paiement** : « Pas encore » / « Payé » / « En plusieurs fois ».
   - Payé → « Réglé en » : Espèces · Carte · Chèque
   - En plusieurs fois → Déjà versé (€), Échéance (date), et Espèces ou Chèque
     (la carte n'a pas besoin de suivi)
7. Bouton d'enregistrement désactivé (`#EBDDE3`) tant que nom + prix + la donnée clé de la
   catégorie manquent ; message d'aide sous le bouton. À l'enregistrement on arrive sur la fiche.

### 6.5 Stats
- Chips de période : Ce mois · 3 derniers mois · Cette année · Depuis toujours · **Période…**
  (→ deux `DatePicker` Du / Au dans une carte bordée).
- **Carte de synthèse** `#B88AA2`, texte blanc : « <période> · encaissé » + le montant en
  44/700 Playfair, puis trois tuiles translucides : En attente · Travaux · Moyen (panier moyen).
- **Donut** 132 pt de diamètre, trou blanc de 88 pt (épaisseur 22), une part par catégorie
  proportionnelle au chiffre, couleurs des catégories ; au centre le total facturé + « facturé ».
  Légende à droite (carré 10 pt + nom + %), puis une ligne par catégorie avec son montant.
  En SwiftUI : `Circle().trim(from:to:).stroke(lineWidth: 22)` empilés, ou `Path.addArc`.
- **Classement en colonnes** : chips Modèles vendus · Réparations · Couleurs · Produits ·
  Meilleures clientes, une phrase d'explication, puis un top 5 en **colonnes verticales** :
  zone de 156 pt, gap 9, ligne de base 1 px `#E8DADA`, valeur au-dessus (12/600), colonne
  (hauteur relative au premier, max 82 %, min 8 pt, rayon `10 10 0 0`, couleur de la catégorie),
  et sous la base le nom tronqué à 15 caractères + le montant. Swift Charts convient.
  Vide : « Rien sur cette période. »

### 6.6 Contacts et fiche cliente
- Contacts : titre + « N clientes », recherche, bouton « Ajouter une cliente » (`#F3E3EA`/`#8A5F79`),
  liste avec avatar rond, nom, « N transactions » ou « Pas encore de transaction », total à droite.
- Nouvelle cliente : Nom et prénom + Téléphone, bouton désactivé tant que le nom est vide.
- Fiche cliente : avatar 56 pt, nom, téléphone, trois tuiles `#F7EDEF`
  (Total dépensé · Travaux · Dernier), section « Historique » avec à droite
  « X € en attente » ou « Tout est payé », puis ses transactions — **une barre verticale de 8 pt
  aux couleurs de l'état** au lieu de la vignette — et un bouton « Nouvelle transaction »
  qui ouvre le formulaire **pré-rempli** avec son nom et son téléphone.

### 6.7 Paramètres
Quatre catalogues, sélectionnés par des chips : **Réparations · Couleurs · Types couleur · Produits**.
Pour chacun : titre + nombre d'entrées, un champ + bouton « Ajouter » (désactivé si vide ou doublon),
puis la liste — point de couleur, nom, « utilisé N× » ou « jamais utilisé », et une croix pour
supprimer. Vide : « Rien ici pour l'instant. Ajoute ta première entrée au-dessus. »
Ce sont ces listes qui alimentent les suggestions du formulaire.

---

## 7. États et interactions
- **Pressé** : lignes de liste → `#F7EDEF` ; boutons principaux → `#A77791` ; boutons bordés → `#F7EDEF`.
- **Focus clavier** : anneau `#B88AA2` 2 pt (sur iOS, le focus natif suffit).
- Pas de chargement, pas d'erreur réseau : tout est local.
- Persistance : **SwiftData** (ou JSON local). Le jeu de 18 transactions du prototype est un
  exemple — l'app livrée démarre vide, avec des états vides propres.

## 8. Assets
Aucun binaire. Icônes = SF Symbols : `house`, `chart.bar`, `person`, `slider.horizontal.3`,
`plus`, `chevron.left`, `chevron.right`, `magnifyingglass`,
`line.3.horizontal.decrease`, `pencil`, `trash`, `xmark`.
Polices Playfair Display + Montserrat à embarquer (.ttf, Google Fonts).
Les tuiles rayées sont des placeholders : à remplacer par les vraies photos.

## 9. Fichiers de ce dossier
- `README.md` — ce document, la source de vérité
- `PROMPT.md` — le texte à coller dans Claude Code
- `Suivi Client v3.dc.html` + `support.js` — le prototype interactif de référence
