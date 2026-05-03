import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _didInitValues = false;

  @override
  void dispose() {
    _nameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sin sesión activa')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(context, title: 'Hogar familiar'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final displayName =
              (data['displayName'] as String?) ??
              user.displayName ??
              user.email?.split('@').first ??
              'Usuario';
          final photoUrl = (data['photoUrl'] as String?) ?? user.photoURL ?? '';

          if (!_didInitValues) {
            _nameController.text = displayName;
            _photoUrlController.text = photoUrl;
            _didInitValues = true;
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 8,
              24,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _ProfileHeader(
                displayName: _nameController.text.trim().isEmpty
                    ? displayName
                    : _nameController.text.trim(),
                photoUrl: _photoUrlController.text.trim(),
              ),
              const SizedBox(height: 24),
              CozyCard(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                padding: const EdgeInsets.all(20),
                child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Editar perfil',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            hintText: 'Ej: Sarah Jenkins',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresá un nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _photoUrlController,
                          decoration: const InputDecoration(
                            labelText: 'URL del avatar (opcional)',
                            hintText: 'https://...',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Si el avatar no carga, se muestran iniciales automáticamente.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _authService.updateProfile(
        displayName: _nameController.text,
        photoUrl: _photoUrlController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el perfil. Intentá nuevamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.displayName, required this.photoUrl});

  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CozyCard(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Center(
            child: Stack(
            clipBehavior: Clip.none,
            children: [
              _AvatarCircle(displayName: displayName, photoUrl: photoUrl),
              Positioned(
                right: -4,
                bottom: -4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.edit_rounded, size: 16, color: scheme.onPrimary),
                  ),
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Coordinación del hogar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.displayName, required this.photoUrl});

  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    const size = 112.0;
    final hasPhoto = photoUrl.trim().isNotEmpty;
    final initials = _buildInitials(displayName);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.secondaryContainer,
      ),
      child: hasPhoto
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _InitialsFallback(initials: initials),
            )
          : _InitialsFallback(initials: initials),
    );
  }

  String _buildInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return (first + last).toUpperCase();
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
