import 'package:flutter_svg/flutter_svg.dart';

import '../core/material.dart';

void showCineAbout(BuildContext context) => showAboutDialog(
  context: context,
  applicationName: 'CineVault',
  applicationIcon: SvgPicture.asset(
    'assets/images/branding/cinevault_emblem.svg',
    width: 48,
    height: 48,
  ),
  children: const [
    Text('Developed by Sudheer Prajapati'),
    SizedBox(height: 10),
    Text(
      'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    ),
  ],
);
