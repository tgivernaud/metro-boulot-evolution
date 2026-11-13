# Plan technique iPhone

## Stack
- Godot 4.x, scènes 3D, GDScript, moteur de rendu Mobile/Compatibility selon tests.
- GitHub pour versionnement et revue.
- Assets glTF/GLB et textures optimisées; source et licences enregistrées dans ASSET_REGISTER.md.
- Builds iOS nécessitant Xcode sur macOS et une signature Apple. Ne pas prétendre qu'une application iOS a été compilée avant validation.
- Le prototype Three.js existant reste disponible sur GitHub Pages mais n'est plus la base technique du nouveau jeu.

## Étapes
1. Prototype Godot minimal : personnage animé, caméra tactile, collisions et une rue.
2. Direction artistique : pack de bâtiments et mobilier cohérents, textures, lumière, personnage animé.
3. Vertical slice : appartement, bureau, café, une mission complète, HUD, sauvegarde.
4. QA sur iPhone réel : ergonomie, performances, chargement, bugs.
5. Signature et distribution iOS : TestFlight/App Store si compte développeur disponible; sinon tester d'abord sur une plateforme de développement adaptée.

## Principes
- Aucun achat, crédit d'agent, service cloud ou publication payante sans validation explicite.
- Préférer un pipeline de build automatisé vérifiable à des manipulations répétées.
- Définition de terminé : build jouable testé sur l'appareil cible, pas uniquement fichiers commités.
