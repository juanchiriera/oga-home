import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeDraft {
  RecipeDraft({
    required this.titulo,
    required this.descripcion,
    required this.ingredientes,
    required this.pasos,
    required this.tiempoMin,
    required this.porciones,
    required this.favorita,
    required this.tags,
  });

  factory RecipeDraft.empty() {
    return RecipeDraft(
      titulo: '',
      descripcion: '',
      ingredientes: const [],
      pasos: const [],
      tiempoMin: 15,
      porciones: 2,
      favorita: false,
      tags: const [],
    );
  }

  factory RecipeDraft.fromFirestore(Map<String, dynamic> data) {
    return RecipeDraft(
      titulo: (data['titulo'] as String? ?? '').trim(),
      descripcion: (data['descripcion'] as String? ?? '').trim(),
      ingredientes: _fromDynamicList(data['ingredientes']),
      pasos: _fromDynamicList(data['pasos']),
      tiempoMin: _toPositiveInt(data['tiempoMin'], fallback: 15),
      porciones: _toPositiveInt(data['porciones'], fallback: 2),
      favorita: data['favorita'] as bool? ?? false,
      tags: _fromDynamicList(data['tags']),
    );
  }

  final String titulo;
  final String descripcion;
  final List<String> ingredientes;
  final List<String> pasos;
  final int tiempoMin;
  final int porciones;
  final bool favorita;
  final List<String> tags;

  String? validationError() {
    if (titulo.trim().isEmpty) {
      return 'El titulo es obligatorio.';
    }
    if (descripcion.trim().isEmpty) {
      return 'La descripcion es obligatoria.';
    }
    if (ingredientes.isEmpty) {
      return 'Agregá al menos un ingrediente.';
    }
    if (pasos.isEmpty) {
      return 'Agregá al menos un paso.';
    }
    if (tiempoMin <= 0) {
      return 'El tiempo debe ser mayor a 0.';
    }
    if (porciones <= 0) {
      return 'Las porciones deben ser mayores a 0.';
    }
    return null;
  }

  Map<String, dynamic> toFirestore({
    required String uid,
    required bool isCreate,
  }) {
    final map = <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'ingredientes': ingredientes,
      'pasos': pasos,
      'tiempoMin': tiempoMin,
      'porciones': porciones,
      'favorita': favorita,
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'clientUpdatedAt': Timestamp.now(),
      'conflictPolicy': 'lww-v1',
    };
    if (tags.isNotEmpty) {
      map['tags'] = tags;
    } else if (!isCreate) {
      map['tags'] = FieldValue.delete();
    }
    if (isCreate) {
      map['createdBy'] = uid;
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  static List<String> parseMultiline(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> parseTags(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _fromDynamicList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  static int _toPositiveInt(Object? value, {required int fallback}) {
    if (value is int && value > 0) {
      return value;
    }
    return fallback;
  }
}
