# Déployer le pont Google Drive — à faire une seule fois

Ça prend 5 minutes. Fais-le depuis un ordinateur (pas depuis l'iPhone), avec le compte
Google dont tu veux utiliser le Drive.

## 1. Crée (ou choisis) le dossier Drive partagé

Sur [drive.google.com](https://drive.google.com), crée un dossier (ex. "SuiviClientData")
ou ouvre celui que tu veux utiliser. Ouvre-le, regarde l'adresse dans la barre du
navigateur : elle ressemble à

```
https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUvWxYz
```

La partie après `folders/` (ici `1AbCdEfGhIjKlMnOpQrStUvWxYz`) est l'**identifiant du
dossier**. Garde-le sous la main pour l'étape 3.

## 2. Crée le script

1. Va sur [script.google.com](https://script.google.com) (connecté avec le même compte
   Google que le dossier ci-dessus).
2. Clique sur **Nouveau projet**.
3. Efface tout le code qui apparaît par défaut, et colle à la place tout le contenu du
   fichier **`Code.gs`** (dans ce même dossier `google-apps-script/`).
4. En haut, donne un nom au projet, par exemple "Suivi Client — pont Drive" (icône crayon
   à côté de "Projet sans titre").

## 3. Renseigne l'identifiant du dossier

Dans le code que tu viens de coller, tout en haut, remplace :

```js
var FOLDER_ID = 'COLLE_ICI_L_IDENTIFIANT_DU_DOSSIER_DRIVE';
```

par l'identifiant récupéré à l'étape 1, entre les guillemets. Ne touche pas à la ligne
`SECRET` juste en dessous — elle doit rester exactement comme dans le fichier.

Sauvegarde (icône disquette, ou `Cmd+S`).

## 4. Déploie comme "application web"

1. En haut à droite, clique sur **Déployer → Nouveau déploiement**.
2. À côté de "Sélectionner le type", clique sur l'icône ⚙️ et choisis **Application web**.
3. Règle les options :
   - **Exécuter en tant que** : Moi (ton adresse Gmail)
   - **Qui a accès** : **Tout le monde**
4. Clique sur **Déployer**.
5. Google va demander d'autoriser le script à accéder à ton Drive — c'est normal
   (c'est le script, pas l'app iPhone, qui accède à ton Drive). Accepte, y compris
   l'écran "Google n'a pas vérifié cette application" → **Paramètres avancés** →
   **Accéder à [nom du projet] (non sécurisé)** → **Autoriser**. C'est ton propre
   script, ce message apparaît juste parce qu'il n'est pas publié sur le store Google.
6. Une **URL de l'application web** apparaît, du genre :
   `https://script.google.com/macros/s/AKfycb.../exec`

## 5. Donne-moi cette URL

Copie cette adresse et envoie-la moi (dans notre conversation). Je la mets dans l'app,
et à partir de là les deux iPhone (une fois l'app mise à jour) liront et écriront
automatiquement dans ce dossier Drive — sans aucun réglage à faire sur les téléphones.

## Si tu dois changer de dossier plus tard

Reviens dans script.google.com, change `FOLDER_ID` dans le code, sauvegarde, puis
**Déployer → Gérer les déploiements → ✏️ (modifier) → Déployer** pour republier sur la
même URL (pas besoin de m'en redonner une nouvelle).

## Liste de secours (Google Sheets)

Le script tient à jour, chaque nuit vers 3 h, un Google Sheets **« Liste de secours »**
dans le dossier Drive de l'app : toutes les fiches (cliente, téléphone, article, prix,
paiement, statut, dates, note), lisibles sans l'app. Un onglet par jour, le plus récent
en premier ; les 14 derniers jours sont gardés.

À activer une seule fois : dans script.google.com, ouvre le projet, choisis
**`installerListeDeSecours`** dans la liste des fonctions en haut (à côté de ▶ Exécuter),
clique sur **▶ Exécuter**, puis autorise l'accès à Google Sheets. La liste du jour est
créée tout de suite ; les suivantes se font seules.
