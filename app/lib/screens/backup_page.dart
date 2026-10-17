import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../common.dart';
import '../data/store.dart';

/// Manual backup: export everything to a file, or restore from one.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  void _done(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    await attempt(context, f);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _export() => _run(() async {
    final json = await store.exportJson();
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Guardar copia de seguridad',
      fileName: 'diario-${ymd(today())}.json',
      bytes: utf8.encode(json),
      mimeType: 'application/json',
    );
    if (uri != null) _done('Copia guardada ✓');
  });

  Future<void> _restore() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Elegí una copia de Diario');
    if (files.isEmpty || !mounted) return;
    final ok = await confirm(
      context,
      'Esto reemplaza TODOS los datos actuales por los de la copia "${files.single.name}". ¿Seguir?',
      action: 'Restaurar',
    );
    if (!ok) return;
    await _run(() async {
      await store.importJson(await files.single.xFile.readAsString());
      _done('Datos restaurados ✓');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Todos tus datos se guardan solo en este celular. Hacé una copia de vez en cuando y guardala en '
            'Drive, mandátela por mail o pasala a la compu, así no perdés nada si cambiás o perdés el celu.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.save_alt_rounded),
            label: const Text('Hacer copia'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restaurar desde una copia'),
          ),
          const SizedBox(height: 16),
          const EmptyHint('Restaurar borra lo que hay ahora y lo reemplaza por el contenido de la copia.'),
        ],
      ),
    );
  }
}
