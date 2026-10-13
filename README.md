# MDT-SAS — Sentinel Security Agency

Ressource FiveM portable pour la tablette opérationnelle de la S.A.S. : dispatch, partenaires, passages, GPS d'agents et rapports.

## Compatibilité

- **Système serveur** : Windows et Linux (FXServer).
- **Framework RP** : Standalone en natif ; ESX, QBCore et Qbox peuvent tourner à côté car la ressource ne dépend d'aucune API framework.
- **Base de données** : MySQL/MariaDB via **oxmysql** recommandé. Sans oxmysql, le MDT démarre en mode mémoire, mais les données sont perdues au redémarrage.
- **Suivi GPS** : OneSync doit être activé pour obtenir des coordonnées serveur fiables.

La compatibilité générale est visée ; il faut tester sur le FXServer, l'artifact et les ressources exactes de chaque serveur avant la production.

## Installation

1. Copier ce dossier sous `resources/[local]/mdt-sas`.
2. Installer et configurer oxmysql si la persistance est nécessaire.
3. Importer `sql/install.sql` dans la base MySQL/MariaDB utilisée par le serveur.
4. Dans `server.cfg`, démarrer oxmysql avant MDT-SAS :
   ```cfg
   ensure oxmysql
   ensure mdt-sas
   ```
5. Ajouter les droits ACE adaptés. Exemple pour le groupe admin :
   ```cfg
   add_ace group.admin mdt.sas.admin allow
   add_ace group.admin mdt.sas.supervisor allow
   add_ace group.admin mdt.sas.dispatch allow
   ```
6. Ajouter les membres autorisés au groupe approprié avec les mécanismes ACE de ton serveur.
7. Modifier `config.lua` et renseigner chaque partenaire : identifiant unique, nom, adresse, objectif quotidien, consignes et coordonnées GTA `x`, `y`, `z`.
8. Redémarrer la ressource avec `restart mdt-sas`.

Les permissions sont contrôlées côté serveur. Les boutons de l'interface ne remplacent jamais ces contrôles.

## Utilisation

- `/sentinel` ou touche F6 : ouvrir/fermer le MDT.
- Prendre son service pour apparaître dans le suivi GPS.
- Un dispatch ne peut être pris que par un agent en service ; son statut et sa position remontent au MDT.
- Le superviseur peut valider ou refuser un passage après vérification de la position et du contexte RP.
- `/mdtcoords` (permission `mdt.sas.admin`) : relève les coordonnées du personnage et les écrit dans la console serveur. Utilise-les pour configurer les partenaires.
- Les passages sont limités par un délai anti-double-clic configurable.

## Passages et preuves photo

1. Configurer les coordonnées du partenaire dans `config.lua`.
2. L'agent doit être en service et se trouver à moins de `Config.PassageValidationDistance` mètres du partenaire.
3. Le formulaire demande une URL HTTPS de preuve photo hébergée par un service approuvé.
4. Le passage reste en statut `pending_review` et ne compte **pas** dans le quota tant qu'un superviseur ne l'a pas validé.
5. Une preuve URL ne garantit pas à elle seule l'authenticité de l'image. En production, branche une ressource de capture qui génère des références signées ou vérifiables, puis restreins les domaines acceptés.

La capture photo automatique n'est pas intégrée dans cette base : elle dépend de la ressource de capture et du service de stockage choisis par le serveur.

## Persistance et quotas

- Les tables sont définies dans `sql/install.sql`.
- Les profils d'agents, dispatchs, passages, rapports et événements de revue sont stockés avec oxmysql.
- Le quota quotidien compte seulement les passages au statut `validated`.
- La date de quota utilise l'heure locale du processus FXServer : règle le fuseau horaire de l'hôte pour obtenir la remise à zéro à minuit dans le fuseau voulu.
- Sans oxmysql ou sans import du schéma, la ressource passe en mémoire temporaire ; ne considère pas ce mode comme adapté à la production.

## Limites connues de cette version

- Le suivi GPS montre les coordonnées serveur et permet de placer un waypoint ; ce n'est pas encore une carte de flotte intégrée avec icônes animées.
- L'authentification de métier/grade ESX/QBCore/Qbox n'est pas encore branchée ; les droits s'appuient sur ACE.
- Le système de photo automatique et l'envoi vers Discord ne sont pas encore intégrés.
- Teste les migrations, droits ACE, redémarrages, reconnexions et passages répétés sur un serveur de test avant la mise en production.

## Arborescence

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
