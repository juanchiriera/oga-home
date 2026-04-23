import 'package:craftr_mobile/features/recipes/recipe_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsea multilinea y tags descartando vacíos', () {
    expect(RecipeDraft.parseMultiline('harina\n\n leche \n'), [
      'harina',
      'leche',
    ]);
    expect(RecipeDraft.parseTags('rápida, horno, , vegetariana '), [
      'rápida',
      'horno',
      'vegetariana',
    ]);
  });

  test('valida campos obligatorios de receta manual', () {
    final invalid = RecipeDraft.empty();
    expect(invalid.validationError(), isNotNull);

    final valid = RecipeDraft(
      titulo: 'Tortilla de papa',
      descripcion: 'Receta base de casa.',
      ingredientes: const ['Papa', 'Huevo'],
      pasos: const ['Pelar', 'Cocinar'],
      tiempoMin: 30,
      porciones: 4,
      favorita: true,
      tags: const ['familiar'],
    );
    expect(valid.validationError(), isNull);
  });
}
