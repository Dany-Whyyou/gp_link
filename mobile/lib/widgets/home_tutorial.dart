import 'package:flutter/material.dart';
import 'package:gp_link/config/theme.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomeTutorialTargets {
  final GlobalKey announcementsTab;
  final GlobalKey alertsTab;
  final GlobalKey messagesTab;
  final GlobalKey profileTab;
  final GlobalKey publishFab;

  HomeTutorialTargets({
    required this.announcementsTab,
    required this.alertsTab,
    required this.messagesTab,
    required this.profileTab,
    required this.publishFab,
  });
}

class HomeTutorial {
  final HomeTutorialTargets targets;
  final VoidCallback onFinish;

  HomeTutorial({required this.targets, required this.onFinish});

  void show(BuildContext context) {
    final tutorial = TutorialCoachMark(
      targets: _buildTargets(),
      colorShadow: AppTheme.primaryNavy,
      paddingFocus: 8,
      opacityShadow: 0.85,
      textSkip: 'PASSER',
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      onFinish: () {
        onFinish();
      },
      onSkip: () {
        onFinish();
        return true;
      },
    );
    tutorial.show(context: context);
  }

  List<TargetFocus> _buildTargets() {
    return [
      _target(
        id: 'announcements',
        key: targets.announcementsTab,
        title: 'Trouvez un voyageur',
        description:
            'Parcourez les annonces publiées par d\'autres voyageurs pour envoyer votre colis.',
        shape: ShapeLightFocus.RRect,
      ),
      _target(
        id: 'publish',
        key: targets.publishFab,
        title: 'Publiez votre voyage',
        description:
            'Vous voyagez ? Publiez votre trajet en quelques secondes et gagnez en transportant des colis.',
        shape: ShapeLightFocus.Circle,
      ),
      _target(
        id: 'alerts',
        key: targets.alertsTab,
        title: 'Créez des alertes',
        description:
            'Définissez vos critères (pays, dates, prix) et recevez une notification dès qu\'une annonce correspond.',
        shape: ShapeLightFocus.RRect,
      ),
      _target(
        id: 'messages',
        key: targets.messagesTab,
        title: 'Chattez en toute sécurité',
        description:
            'Contactez directement les voyageurs via la messagerie intégrée pour organiser le transport.',
        shape: ShapeLightFocus.RRect,
      ),
      _target(
        id: 'profile',
        key: targets.profileTab,
        title: 'Votre profil',
        description:
            'Gérez vos infos, vos annonces, vos paiements, et revoyez ce tutoriel à tout moment.',
        shape: ShapeLightFocus.RRect,
      ),
    ];
  }

  TargetFocus _target({
    required String id,
    required GlobalKey key,
    required String title,
    required String description,
    required ShapeLightFocus shape,
  }) {
    return TargetFocus(
      identify: id,
      keyTarget: key,
      shape: shape,
      radius: 8,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: controller.next,
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      'Suivant',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
