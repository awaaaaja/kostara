import 'package:flutter/material.dart';

/// Dialog alasan wajib (reject/verifikasi, moderasi review).
/// Returns null bila dibatalkan; String ter-trim bila submit.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  String hint = 'Alasan wajib diisi',
}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final canSubmit = ctrl.text.trim().isNotEmpty;
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            maxLength: 300,
            onChanged: (_) => setDialogState(() {}),
            decoration: InputDecoration(hintText: hint, counterText: ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: canSubmit
                  ? () => Navigator.of(dialogContext).pop(ctrl.text.trim())
                  : null,
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    ),
  );
  return result; // null = batal; non-empty (tombol aktif hanya bila terisi)
}

/// Konfirmasi aksi umum (approve/hide/resolve tanpa alasan).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Lanjutkan',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// SnackBar aman setelah aksi admin (tanpa konteks BuildContext tertutup).
void snack(ScaffoldMessengerState messenger, String text) {
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
