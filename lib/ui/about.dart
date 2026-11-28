import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/material.dart';

void showCineAbout(BuildContext context) => showAboutDialog(
  context: context,
  applicationName: 'CineVault',
  applicationIcon: SvgPicture.asset(
    'assets/images/branding/cinevault_emblem.svg',
    width: 48,
    height: 48,
  ),
  children: [
    const Text('Developed by Sudheer Prajapati'),
    const SizedBox(height: 10),
    const Text(
      'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => launchUrl(Uri.https('www.themoviedb.org')),
        icon: SvgPicture.asset(
          'assets/images/branding/tmdb_attribution.svg',
          width: 27,
          height: 20,
          excludeFromSemantics: true,
        ),
        label: const Text('The Movie Database'),
      ),
    ),
  ],
);
