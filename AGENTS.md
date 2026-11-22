# Calculateur d'or — WoW: Forever (niveaux 20–42)

Page HTML autonome (aucun build, aucune dépendance, aucun framework) qui classe des spots de farm
par or/heure pour WoW: Forever. Les prix de l'hôtel des ventes sont récupérés en direct.

Site en ligne : https://gold-per-hour-calculator.netlify.app/

## Contraintes non négociables

- **Tout est en français** : interface, libellés, notes, messages d'erreur, CSV. Seuls les termes WoW
  et les abréviations (`AH`, `Horde`, noms de zones/objets) restent en anglais.
- **Pas de logique de monture** : pas de « Remise Honoré », pas de « Besoin du Dual Spec »,
  pas de « Heures jusqu'à la monture ». La page ne parle que d'or/heure.
- **Référence de données** : `https://www.wowhead.com/forever/` (version Forever, pas Retail ni Classic).
- **Marché AH** : ahprice, serveur `eu-pvp-horde`, faction `horde`, libellé affiché « EU PvP · Horde ».
- **Un seul appel réseau** par synchronisation : `/api/v1/prices?...&ids=...` (50 IDs maximum par requête).
  Auto-refresh toutes les 5 minutes + bouton manuel. Jamais un appel par objet.
- Le site doit rester **un seul fichier HTML** utilisable en double-clic (`file://`).

## Fichiers

| Fichier | Rôle |
|---|---|
| `calculateur-or-papa.html` | Source de vérité. CSS + données + logique dans un seul fichier. |
| `index.html` | Copie exacte servie par Vercel (ne pas éditer : écrasée par `deploy.ps1`). |
| `vercel.json` | Configuration statique Vercel (`cleanUrls`, `Cache-Control: max-age=0`). |
| `deploy.ps1` | Copie vers `index.html` + validation `node --check` + commit & push GitHub (déclenche Vercel). `-LocalOnly` pour ne pas pousser. |

Après toute modification : lancer `.\deploy.ps1` (ou `.\deploy.ps1 -LocalOnly` pour préparer/valider localement sans pousser).
Ne jamais éditer `index.html` : le script l'écrase depuis `calculateur-or-papa.html`.

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy.ps1
```

## Structure du fichier

1. `<style>` — thème sombre, variables CSS (`--gold`, `--green`, `--blue`, `--red`, `--panel`, `--line`).
2. HTML — en-tête + `.stamp`, panneau de réglages (niveau, monstres/h, filtres), 3 KPI, 2 onglets
   (`Zones rentables` / `Aide-mémoire des métiers`), barre AH, tableau, note de méthode.
3. `/*DATA-START*/ … /*DATA-END*/` — **tableau `SPOTS`** (données pures, JSON sur une ligne par spot).
4. `PROFS` — aide-mémoire des métiers (cartes repliables).
5. Logique — `state`, `AH_CFG`, `ahIds()`, `ahPerKill()`, `syncAH()`, `gph()`, `render()`, `exportCsv()`.

Le bloc `SPOTS` est délimité par des marqueurs exprès : on peut le remplacer intégralement par script
sans toucher au reste du fichier.

## Modèle de données `SPOTS`

| Champ | Type | Sens |
|---|---|---|
| `id` | string | Identifiant stable, utilisé par `data-id` et les tests. |
| `zone` / `mob` | string | Zone et monstre/activité affichés. |
| `lo` / `hi` | int | Niveaux **recommandés** pour la zone (pas le niveau des monstres). |
| `mobLvl` | string | Niveau réel des monstres, affiché en petit sous le niveau recommandé. |
| `fac` | `"A"`/`"H"`/`"B"` | Alliance / Horde / les deux. |
| `prof` | string | Métier associé (`Aucune`, `Dépeçage`, `Minage`, `Herboristerie`, `Pêche`). |
| `tags` | `[[texte, classe]]` | Pastilles. Classes : `zero`, `ah`, `skin`, `hot`, `est`. |
| `drops` | string | Butins et taux, texte libre. |
| `raw` | number | Argent **marchand** par unité, en pièces d'argent. |
| `ah` | number | Bonus AH statique par unité (repli si l'API ne répond pas). |
| `pace` | number | Multiplicateur du curseur « monstres/h » (1 = 1 pour 1 ; 0,15 pour les herbes). |
| `unit` | `kill`/`node`/`catch` | Unité comptée : monstre, nœud, prise. |
| `est` | bool | `true` → affiche la pastille ESTIM. (modèle de rendement, pas un taux exact). |
| `ahItems` | `[{id, rate}]` | Objets AH : `rate` = **quantité moyenne par unité** (peut dépasser 1, ex. 2,2 peaux). |

`ahPerKill(s)` somme les `ahItems` valorisés au prix live. Si aucun prix n'est disponible, il retombe
sur `s.ah`. Ne pas réintroduire l'ancien champ `ahItem: {id, base}` (mise à l'échelle) : tout passe
par `ahItems` + `rate`.

## Chaîne AH

```
AH_CFG = { market: "eu-pvp-horde", faction: "horde", label: "EU PvP · Horde",
           base: "https://ahprice.com/api/v1", refreshMs: 5*60*1000 }
```

- Prix retenu : `market_avg_copper`, sinon `true_value_copper`, sinon `latest_floor_copper`.
- `data_age_seconds` = âge du **dernier scan joueur**, pas de la requête : peut dépasser 1 h.
- États de la pastille : `ok` (vert), `loading` (or), `err` (rouge). En cas d'échec, les derniers prix
  sont conservés ; s'il n'y en a jamais eu, les valeurs statiques restent affichées.
- Limites ahprice : 60 requêtes/min et 2 000/jour par IP, prix cachés 60 s.

Endpoints utiles :
- `GET /api/v1/realms`
- `GET /api/v1/items?q=...&realm=eu-pvp-horde&faction=horde&limit=5` → renvoie `item_id`
- `GET /api/v1/items/{id}?realm=...&faction=...`
- `GET /api/v1/prices?realm=eu-pvp-horde&faction=horde&ids=...` → renvoie `name`, donc sert à vérifier un ID

## Sources Wowhead Forever

Le site Wowhead renvoie **403** en `fetch` direct (CloudFront). Passer par le proxy texte :
`https://r.jina.ai/https://www.wowhead.com/forever/npc=XXXX` ou `.../item=XXXX`.

- `npc=ID` → tableau `Drops` avec les pourcentages réels (`| ... | x out of y | NN |`).
- `search?q=...` → les résultats sont dans un `<script type="application/json">` (champ `id`, `minlevel`, `maxlevel`).
- Les onglets `Skinning` ne sont pas toujours rendus : se fier aux objets (`item=`) qui listent les NPC source.

Taux relevés (17 nov. 2026) :

| Sujet | Donnée |
|---|---|
| Whirlwind Shredder (11578) | Elemental Air 67 % |
| Primitive Owlbeast (2928) | Giant Egg 32 % |
| Sparkleshell Snapper (4143) | Turtle Meat 34 % |
| Mudrock Tortoise (4396) | Turtle Meat 37 % |
| Crushridge Ogre (2252) | Silk Cloth 29 %, Mageweave 1,2 % |
| Boulderfist Ogre (2562) | Silk Cloth 28 %, Mageweave 0,5 % |
| Lesser Rock Elemental (2735) | Elemental Earth 9 %, Solid Stone 23 % |
| Stone Golem (2723) | Solid Stone 23 %, Deeprock Salt 24 % |
| Darkmist Spider (4376) | Shadow Silk 5 % |
| Burning Exile (2760) | Elemental Fire 17 % (Air 27 %, Eau 18 %, Terre 11 % sur les 3 autres) |
| Aged Kodo (4700) | Heavy Kodo Meat 36 %, Dirty Kodo Scale 11 %, Thick Kodo Hair 34 % |
| Stranglethorn Tiger (682) | Tiger Meat 52 % |
| Lashtail Raptor (686) | Raptor Hide 38 % |
| Mottled Drywallow Crocolisk (4344) | Tender Crocolisk Meat 58 % |
| Venture Co. Strip Miner (674) | Pages Green Hills ≈ 11 % cumulés, Broken Electro-lantern 30 % |
| Elder Cloud Serpent (4119) | Light Feather 50 % (aucune viande) |
| Searing Hatchling (4323) & Searing Whelp (4324) | Small Flame Sac 14 %, Wicked Claw 2,7 % |
| Crystal Spine Basilisk (689) | Curved Basilisk Claw 30 %, Intact Basilisk Spine 30 %, Large Fang 4 %, Wicked Claw 1,2 % |
| Crimson Whelp (1069) | Small Flame Sac 5 %, Sharp Claw 4 %, Large Fang 1 % |
| Scorched Basilisk (4041) | Scales & Teeth 31 %, Curved Claw 19 %, Spine 18 %, Sharp Claw 6 %, Large Fang 1,4 % |
| Cinderscale Whelp (262473) | Small Flame Sac 13 %, Wicked Claw 2,5 % (zone Forever : Riverglades) |

IDs AH suivis : 3182, 2319, 4232, 4234, 4235, 4304, 4306, 4338, 8169, 7067, 7068, 7069, 7070, 7912, 2776,
2772, 4278, 2838, 10285, 12207, 12202, 12204, 5121, 5122, 3712, 3667, 17056, 4461, 2735, 1630,
3369, 3818, 3821, 3358, 3357, 4402, 5637, 8146, 5635 → 39 objets.

## Modèles d'estimation (lignes ESTIM.)

- **Dépeçage** : 22–29 → 1,8 Medium Leather + 0,1 Medium Hide ; 30–39 → 2,2 Heavy Leather +
  0,1 Heavy Hide ; 40+ → 1,8 Thick Leather + 0,1 Thick Hide (Thick = monstres 40+).
- **Minage** : 1 filon tous les ~3 kobolds (Gold Ore, Iron Ore, Lesser Bloodstone Ore, Heavy Stone).
- **Herbes** : rendement par nœud (Grave Moss ×2 ; Fadeleaf 1,5 + Goldthorn 1 + Khadgar's Whisker 0,5
  + Liferoot 0,5), `pace` 0,15 → ~23 nœuds/h au curseur par défaut.
- **Pêche** : 1 coffre par prise, contenu estimé à 30 s.
- Ne pas gonfler ces valeurs sans source : elles sont affichées comme estimations et la note de bas de
  page explique le modèle au lecteur.

## Déploiement GitHub → Vercel

- Flux continu : **GitHub (branche `main`) → Vercel** (projet statique sans étape de build, Framework Preset : `Other`, Output Directory : `.`).
- `.\deploy.ps1` synchronise `calculateur-or-papa.html` → `index.html`, valide la syntaxe JS, puis fait `git commit` et `git push` vers `origin`, ce qui déclenche automatiquement le déploiement en production sur Vercel.
- Pour un déploiement initial ou manuel via CLI : `npm i -g vercel` puis `vercel --prod`.

## Vérification après déploiement

1. Ouvrir l'URL de production Vercel et recharger (cache `max-age=0`).
2. Console : zéro erreur. Bandeau AH : « 39/39 objets » et pastille verte.
3. 27 lignes. Basculer sur « marchand + AH » : le meilleur spot doit être Chouettards primitifs (~38 g/h au
   curseur 150), puis Kodo, Déchireurs.
4. Tester le repli : couper le réseau, recharger → les valeurs statiques s'affichent sans casser la page.
5. Export CSV : l'en-tête doit contenir les deux colonnes « Or/h marchand uniquement » et
   « Or/h marchand + AH », plus une ligne d'horodatage de la synchro.

## Pièges connus

- Ne pas éditer `index.html` directement : il est écrasé à chaque préparation de déploiement par `deploy.ps1`.
- Le champ `rate` peut être > 1 (quantité par monstre) : c'est volontaire, ne pas le « corriger » en 0–100.
- `mobLvl` est décorrélé de `lo`/`hi` : Owlbeast est recommandé 42+ mais les monstres sont 44–45.
- Les prix changent : ne pas figer le classement dans le code, il est calculé à l'affichage.
- Les accents sont en UTF-8 sans BOM. Écrire les fichiers avec un encodage UTF-8 explicite sous PowerShell.
