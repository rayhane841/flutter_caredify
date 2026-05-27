// ============================================================================
// 🧪 FICHIER DE TEST POUR L'APPLICATION CAREDIFY
// ============================================================================
// Ce fichier sert à tester automatiquement que ton application fonctionne.
// Au lieu de cliquer manuellement sur ton téléphone à chaque modification,
// ce code simule des clics et vérifie que tout se passe comme prévu.
// ============================================================================

// ============================================================================
// 📦 PARTIE 1 : IMPORTER LES OUTILS NÉCESSAIRES
// ============================================================================

//  Importe tous les widgets de base de Flutter
// Exemple : Text, Button, Container, Scaffold, MaterialApp, etc.
import 'package:flutter/material.dart';

// Importe les outils pour écrire des tests
// Exemple : tester.pumpWidget(), expect(), find.text(), etc.
import 'package:flutter_test/flutter_test.dart';

// Importe TON application principale (CaredifyApp)
// C'est comme dire : "Je veux tester l'app qui est dans le fichier main.dart"
import 'package:caredify/main.dart';
import 'package:caredify/providers/language_provider.dart';

// ============================================================================
//  PARTIE 2 : POINT D'ENTRÉE DU TEST
// ============================================================================

//  Fonction principale : c'est ici que le test commence à s'exécuter
void main() {
  //  testWidgets = crée un nouveau test automatisé
  //  'Le compteur s'incrémente correctement' = le nom du test (affiché dans le terminal)
  // (WidgetTester tester) = on reçoit un "robot testeur" qui va simuler les actions
  //  async = ce test contient des opérations asynchrones (qui prennent du temps)
  testWidgets('Le compteur s\'incrémente correctement',
      (WidgetTester tester) async {
    // -------------------------------------------------------------------------
    //  ÉTAPE 1 : LANCER L'APPLICATION DANS LE TEST
    // -------------------------------------------------------------------------

    //  await = attendre que l'opération soit terminée avant de continuer
    //  tester.pumpWidget() = afficher un widget dans un environnement de test virtuel
    // CaredifyApp() = c'est TON application qu'on lance (la même que dans main.dart)
    // Résultat : l'app est "ouverte" dans le test, comme si tu la lançais sur ton téléphone
    final languageProvider = LanguageProvider();
    await tester.pumpWidget(CaredifyApp(languageProvider: languageProvider));

    // -------------------------------------------------------------------------
    // 🔍 ÉTAPE 2 : VÉRIFIER QUE LE COMPTEUR COMMENCE À 0
    // -------------------------------------------------------------------------

    //  expect() = fonction qui vérifie une condition (comme un "if" mais pour les tests)
    // find.text('0') = cherche le texte "0" quelque part dans l'écran
    // findsOneWidget = condition : "doit être trouvé exactement 1 fois"
    // Traduction : "Je m'attends à voir le chiffre 0 à l'écran, et il doit apparaître 1 seule fois"
    expect(find.text('0'), findsOneWidget);

    // find.text('1') = cherche le texte "1" à l'écran
    // findsNothing = condition : "ne doit PAS être trouvé"
    //  Traduction : "Je m'attends à NE PAS voir le chiffre 1 (car on n'a pas encore cliqué)"
    expect(find.text('1'), findsNothing);

    // -------------------------------------------------------------------------
    //  ÉTAPE 3 : SIMULER UN CLIC SUR LE BOUTON "+"
    // -------------------------------------------------------------------------

    // find.byIcon(Icons.add) = cherche un widget qui a l'icône "+" (le bouton add)
    // tester.tap() = simule un doigt qui tape sur ce widget
    // Résultat : le test "clique" virtuellement sur le bouton +
    await tester.tap(find.byIcon(Icons.add));

    //  tester.pump() = dire à Flutter : "met à jour l'écran après le clic"
    // Pourquoi ? Parce que quand on clique, l'interface doit se rafraîchir pour montrer le nouveau chiffre
    await tester.pump();

    // -------------------------------------------------------------------------
    // ÉTAPE 4 : VÉRIFIER QUE LE COMPTEUR A CHANGÉ (0 → 1)
    // -------------------------------------------------------------------------

    //  Maintenant on vérifie l'inverse : le 0 a disparu, le 1 est apparu
    expect(find.text('0'), findsNothing); //  Le "0" ne doit plus être visible
    expect(find.text('1'),
        findsOneWidget); //  Le "1" doit maintenant être visible

    // Si ces deux vérifications passent = le test est RÉUSSI ✅
    // Si l'une échoue = le test est ÉCHOUÉ ❌ (et Flutter te dit exactement quoi corriger)
  }); // ← Fin du test "Le compteur s'incrémente correctement"
} // ← Fin de la fonction main()
