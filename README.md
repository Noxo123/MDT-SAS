# MDT-SAS — Sentinel Security Agency

Base de ressource FiveM indépendante du système d'exploitation et du framework.

## Compatibilité visée
- Serveur FXServer sous Windows ou Linux.
- ESX, QBCore, Qbox ou Standalone : la base fonctionne sans dépendance obligatoire à ces frameworks.
- NUI HTML/CSS/JavaScript et logique client/serveur Lua.
- Permissions contrôlées côté serveur via ACE.

> Cette première base fournit les fondations fonctionnelles du MDT. Elle ne prétend pas intégrer automatiquement les scripts tiers de téléphone, capture photo, inventaire ou gestion d'entreprise. Ces intégrations doivent être configurées et testées séparément.

## Installation
1. Copier le dossier `mdt-sas` dans `resources/[local]/`.
2. Ajouter à `server.cfg` :
   ```cfg
   ensure mdt-sas
   ```
3. Configurer les permissions ACE dans `server.cfg` (exemple plus bas).
4. Modifier les partenaires et réglages dans `config.lua`.
5. Redémarrer la ressource.

### Permissions ACE d'exemple
Adapte les identifiants aux groupes de ton serveur :
```cfg
add_ace group.admin mdt.sas.admin allow
add_ace group.admin mdt.sas.dispatch allow
add_ace group.admin mdt.sas.supervisor allow

# Exemple pour un joueur précis :
# add_principal identifier.license:TON_IDENTIFIANT group.admin
```

Les droits sont vérifiés côté serveur. Cacher un bouton dans l'interface ne constitue jamais une protection.

## Utilisation
- Ouvrir/fermer la tablette : commande `/sentinel` ou touche configurable.
- Créer et prendre en charge un dispatch.
- Consulter les partenaires et enregistrer un passage.
- Les positions des agents en service sont publiées périodiquement par le serveur.
- Les rapports sont stockés en mémoire dans cette base initiale. Pour une persistance après redémarrage, installer oxmysql et appliquer `sql/install.sql`, puis connecter les requêtes dans la couche de stockage.

## Captures photo
La preuve photo doit venir d'une ressource de capture réellement installée. Cette base enregistre une référence/URL de preuve facultative, mais ne simule pas une capture. N'accepte que des preuves provenant d'un système approuvé par le serveur.

## Sécurité et limites actuelles
- Le serveur contrôle les droits, les identifiants de mission et le quota de passage.
- Les positions sont lues côté serveur depuis l'entité du joueur (OneSync requis pour un suivi fiable).
- Les quotas sont quotidiens et remis à zéro logiquement selon l'heure serveur ; l'historique de cette base mémoire est perdu au redémarrage.
- Ajouter une couche de persistance SQL et une intégration de framework si tu souhaites lire automatiquement les métiers/grades ESX, QBCore ou Qbox.
- Tester sur un serveur de développement avant production.

## Structure
```
mdt-sas/
├── fxmanifest.lua
├── config.lua
├── client/main.lua
├── server/main.lua
├── web/index.html
├── web/style.css
├── web/app.js
└── sql/install.sql
```
