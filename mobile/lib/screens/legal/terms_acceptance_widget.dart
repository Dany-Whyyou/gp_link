import 'package:flutter/material.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAcceptanceWidget extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const TermsAcceptanceWidget({
    super.key,
    required this.accepted,
    required this.onChanged,
  });

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withValues(alpha: 0.08),
            border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: AppTheme.accentOrange),
                  SizedBox(width: 8),
                  Text(
                    'Important — responsabilité du transport',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'GP Link est uniquement une plateforme de mise en relation. '
                'Nous ne transportons aucun colis.\n\n'
                'En tant que voyageur, vous êtes SEUL responsable de ce que '
                'vous transportez. Vérifiez OBLIGATOIREMENT le contenu des '
                'colis avant de les accepter.\n\n'
                'Le transport de produits illicites (drogues, armes, '
                'contrefaçons, espèces protégées, etc.) relève de votre '
                'responsabilité pénale et civile exclusive.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => onChanged(!accepted),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: accepted,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: AppTheme.primarySky,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 13),
                        children: [
                          const TextSpan(text: 'J\'ai lu et j\'accepte les '),
                          TextSpan(
                            text: 'Conditions Générales d\'Utilisation',
                            style: const TextStyle(
                              color: AppTheme.primarySky,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: null,
                          ),
                          const TextSpan(text: ' et la '),
                          TextSpan(
                            text: 'Politique de confidentialité',
                            style: const TextStyle(
                              color: AppTheme.primarySky,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Row(
            children: [
              TextButton(
                onPressed: () => _openUrl(AppConstants.termsUrl),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Lire les CGU', style: TextStyle(fontSize: 12)),
              ),
              const Text(' • ', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: () => _openUrl(AppConstants.privacyUrl),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Confidentialité',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
