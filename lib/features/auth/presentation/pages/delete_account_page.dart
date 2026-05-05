import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../provider/auth_provider.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  String? _lastMessage;
  String? _lastWebUrl;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF111111);
    const card = Color(0xFF1A1A1A);
    const gold = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Eliminar cuenta'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: gold.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Cuenta de cliente',
                        style: TextStyle(
                          color: gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Esta accion elimina el acceso a tu cuenta en la app Hábito.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Antes de continuar, ten en cuenta lo siguiente:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _DeleteAccountPoint(
                      icon: Icons.event_busy_outlined,
                      text: 'Las citas futuras asociadas a tu cuenta seran canceladas.',
                    ),
                    const _DeleteAccountPoint(
                      icon: Icons.notifications_off_outlined,
                      text: 'Tus sesiones y notificaciones push dejaran de estar activas.',
                    ),
                    const _DeleteAccountPoint(
                      icon: Icons.receipt_long_outlined,
                      text:
                          'Los pedidos o comprobantes ya emitidos se conservaran solo cuando exista una razon operativa o tributaria para hacerlo.',
                    ),
                    const SizedBox(height: 16),
                    if ((_lastMessage ?? '').isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121A14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF3F8F62),
                          ),
                        ),
                        child: Text(
                          _lastMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE6FFF0),
                            height: 1.45,
                          ),
                        ),
                      ),
                    if ((_lastMessage ?? '').isNotEmpty) const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: auth.isLoading ? null : _requestDeletion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: auth.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.mail_outline_rounded),
                        label: Text(
                          auth.isLoading
                              ? 'Enviando confirmacion...'
                              : 'Enviar enlace de eliminacion',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _openDeletionWebPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_browser_outlined),
                        label: const Text(
                          'Abrir pagina web de eliminacion',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Te enviaremos un enlace a tu correo para confirmar la eliminacion. La cuenta seguira activa hasta que completes esa confirmacion.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestDeletion() async {
    final response = await context.read<AuthProvider>().requestAccountDeletion();

    if (!mounted) return;

    if (response == null) {
      final message =
          context.read<AuthProvider>().error ??
          'No pudimos iniciar la solicitud de eliminacion.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() {
      _lastMessage = response['message'];
      _lastWebUrl = response['webUrl'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['message'] ??
              'Te enviamos un enlace para confirmar la eliminacion.',
        ),
      ),
    );
  }

  Future<void> _openDeletionWebPage() async {
    final url = _lastWebUrl ?? _defaultDeletionWebUrl;
    final uri = Uri.tryParse(url);

    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir la pagina web de eliminacion.'),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir la pagina web de eliminacion.'),
      ),
    );
  }

  String get _defaultDeletionWebUrl {
    final apiUri = Uri.parse(AppConfig.apiBaseUrl);
    return apiUri
        .replace(
          path: '/',
          queryParameters: const {'habito_delete_account': '1'},
          fragment: null,
        )
        .toString();
  }
}

class _DeleteAccountPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DeleteAccountPoint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFD4AF37),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
