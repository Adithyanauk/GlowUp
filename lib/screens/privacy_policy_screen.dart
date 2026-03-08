import 'package:flutter/material.dart';
import '../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _effectiveDate = 'March 1, 2026';
  static const _contactEmail = 'support@glowupapp.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Text(
            'Privacy Policy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Effective date: $_effectiveDate',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextHint,
            ),
          ),
          const SizedBox(height: 24),

          _body(context, '''
GlowUp ("we", "our", or "us") operates the GlowUp mobile application (the "App"). This Privacy Policy informs you of our policies regarding the collection, use, and disclosure of personal information when you use our App.

By using the App, you agree to the collection and use of information in accordance with this policy.'''),

          _heading(context, '1. Information We Collect'),
          _body(context, '''
a) Personal Data
We do not collect any personally identifiable information (PII) such as your name, email address, phone number, or physical address.

b) Usage Data
GlowUp stores your workout progress, streak data, fitness level preference, and app settings (such as theme preference) locally on your device using SharedPreferences. This data never leaves your device.

c) Device Information
We do not collect device identifiers, IP addresses, browser type, or any other device-specific information.'''),

          _heading(context, '2. How We Use Your Information'),
          _body(context, '''
The locally stored data is used solely to:
• Track your 30-day workout challenge progress
• Display your current and best streaks
• Remember your theme and personalization preferences
• Resume your challenge from where you left off

We do not use your data for advertising, profiling, or any purpose other than providing the core functionality of the App.'''),

          _heading(context, '3. Data Storage and Security'),
          _body(context, '''
All your data is stored locally on your device. We do not operate any servers, databases, or cloud infrastructure that stores your personal data. Since your data remains on your device, its security is governed by the security of your device and operating system.

You can delete all your data at any time by using the "Delete all data" option in the Settings screen of the App.'''),

          _heading(context, '4. Third-Party Services'),
          _body(context, '''
The App does not integrate any third-party analytics, advertising, or tracking services. We do not share, sell, or transfer your data to any third parties.

The App may include links to external services (such as the Google Play Store for rating or an email client for feedback). These external services have their own privacy policies, and we encourage you to review them.'''),

          _heading(context, '5. Children\'s Privacy'),
          _body(context, '''
GlowUp is suitable for users of all ages. We do not knowingly collect personal information from anyone, including children under 13. Since all data is stored locally and no personal information is transmitted, the App complies with the Children's Online Privacy Protection Act (COPPA) and similar regulations.'''),

          _heading(context, '6. Permissions'),
          _body(context, '''
The App may request the following permissions:
• Internet access — Required for the "Share App" and "Rate Us" features to open external links. The App does not transmit any user data over the internet.
• No other sensitive permissions are required.'''),

          _heading(context, '7. Data Retention'),
          _body(context, '''
Your data is retained locally on your device for as long as the App is installed. Uninstalling the App or using the "Delete all data" option will permanently remove all stored data. We do not retain any copies of your data.'''),

          _heading(context, '8. Your Rights'),
          _body(context, '''
You have the right to:
• Access your data — All data is visible within the App (progress, streaks, settings).
• Delete your data — Use the "Delete all data" option in Settings to erase all stored data at any time.
• Opt out — Since we do not collect or transmit data, there is nothing to opt out of.'''),

          _heading(context, '9. Changes to This Privacy Policy'),
          _body(context, '''
We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy within the App and updating the "Effective date" at the top. You are advised to review this Privacy Policy periodically for any changes.'''),

          _heading(context, '10. Contact Us'),
          _body(context, '''
If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us:

Email: $_contactEmail'''),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String text) {
    return Text(
      text.trim(),
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: context.appTextSecondary,
      ),
    );
  }
}
