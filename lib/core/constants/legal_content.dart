/// Long-form legal copy for the Terms of Service and Privacy Policy screens.
///
/// This is a plain-language starting template, not legal advice. Have it
/// reviewed by an attorney before App Store submission.
class LegalSection {
  final String heading;
  final String body;

  const LegalSection({required this.heading, required this.body});
}

abstract final class LegalContent {
  static const String companyName = 'MindsetForge';
  static const String contactEmail = 'mindsetforge.ai@gmail.com';
  static const String effectiveDate = 'June 23, 2026';
  static const String governingLaw =
      'the State of California, United States, with venue in Riverside County, '
      'California';

  // ─── Terms of Service ──────────────────────────────────────────────────────

  static const List<LegalSection> terms = [
    LegalSection(
      heading: '1. Acceptance of Terms',
      body:
          'Welcome to $companyName. These Terms of Service ("Terms") govern your '
          'access to and use of the $companyName mobile application and related '
          'services (the "Service"). By creating an account or using the Service, '
          'you agree to be bound by these Terms. If you do not agree, do not use '
          'the Service.',
    ),
    LegalSection(
      heading: '2. Eligibility',
      body:
          'You must be at least 18 years old, or the age of majority in your '
          'jurisdiction, to use the Service. By using $companyName you represent '
          'and warrant that you meet this requirement and that the information you '
          'provide is accurate.',
    ),
    LegalSection(
      heading: '3. Description of the Service',
      body:
          '$companyName is a personal-development application that provides '
          'AI-assisted mindset coaching, journaling, goal and habit tracking, '
          'affirmations, and related self-improvement tools. Coaching responses '
          'are generated with the assistance of artificial intelligence and are '
          'provided for informational and motivational purposes only.',
    ),
    LegalSection(
      heading: '4. Not Therapy or Medical Advice',
      body:
          '$companyName is a mindset and personal-growth coach. It is not therapy, '
          'counseling, or medical care, and it is not a substitute for advice, '
          'diagnosis, or treatment from a licensed mental-health professional, '
          'physician, or other qualified provider. Do not disregard or delay '
          'seeking professional help because of anything you read in the Service. '
          'If you are experiencing a crisis or thinking about harming yourself or '
          'others, contact emergency services (911 in the US) or the 988 Suicide '
          'and Crisis Lifeline (call or text 988) immediately. The Service does '
          'not provide emergency or crisis services.',
    ),
    LegalSection(
      heading: '5. Subscriptions and Billing',
      body:
          'Some features require a paid subscription. Subscriptions are processed '
          'through the applicable app store and managed via our payments provider '
          '(RevenueCat). Subscriptions automatically renew unless canceled at '
          'least 24 hours before the end of the current period, and your account '
          'will be charged for renewal within 24 hours prior to the end of the '
          'period. You can manage or cancel your subscription in your app store '
          'account settings. Except where required by law, payments are '
          'non-refundable.',
    ),
    LegalSection(
      heading: '6. Acceptable Use',
      body:
          'You agree not to misuse the Service, including by attempting to access '
          'it through unauthorized means, reverse engineering it, using it to '
          'violate any law, harass others, or submit content that is unlawful or '
          'infringing. You are responsible for keeping your account credentials '
          'secure and for all activity under your account.',
    ),
    LegalSection(
      heading: '7. Your Content',
      body:
          'You retain ownership of the content you create in the Service, such as '
          'journal entries, goals, and messages. You grant $companyName a limited '
          'license to store and process this content solely to operate and improve '
          'the Service for you, including sending relevant context to our AI '
          'provider to generate personalized responses.',
    ),
    LegalSection(
      heading: '8. Intellectual Property',
      body:
          'The Service, including its software, design, and content (excluding '
          'your content), is owned by $companyName and protected by intellectual '
          'property laws. These Terms do not grant you any right to use our '
          'trademarks or branding without prior written permission.',
    ),
    LegalSection(
      heading: '9. Disclaimers',
      body:
          'The Service is provided "as is" and "as available" without warranties '
          'of any kind, whether express or implied, including fitness for a '
          'particular purpose and non-infringement. We do not warrant that the '
          'Service will be uninterrupted, error-free, or that AI-generated content '
          'will be accurate, complete, or suitable for your situation.',
    ),
    LegalSection(
      heading: '10. Limitation of Liability',
      body:
          'To the maximum extent permitted by law, $companyName and its affiliates '
          'will not be liable for any indirect, incidental, special, '
          'consequential, or punitive damages, or any loss of data, profits, or '
          'goodwill, arising from your use of the Service. Our total liability for '
          'any claim relating to the Service will not exceed the amount you paid '
          'us in the twelve months before the claim.',
    ),
    LegalSection(
      heading: '11. Termination',
      body:
          'You may stop using the Service and delete your account at any time from '
          'the in-app settings. We may suspend or terminate your access if you '
          'violate these Terms or to protect the Service or other users. Sections '
          'intended to survive termination will continue to apply.',
    ),
    LegalSection(
      heading: '12. Changes to These Terms',
      body:
          'We may update these Terms from time to time. If we make material '
          'changes, we will provide notice within the Service or by other '
          'reasonable means. Your continued use of the Service after changes take '
          'effect constitutes acceptance of the updated Terms.',
    ),
    LegalSection(
      heading: '13. Governing Law',
      body:
          'These Terms are governed by the laws of $governingLaw, without regard '
          'to its conflict-of-laws principles. You agree to the exclusive '
          'jurisdiction of the courts located there for any dispute that is not '
          'subject to arbitration or small-claims resolution.',
    ),
    LegalSection(
      heading: '14. Contact Us',
      body:
          'Questions about these Terms? Contact us at $contactEmail.',
    ),
  ];

  // ─── Privacy Policy ────────────────────────────────────────────────────────

  static const List<LegalSection> privacy = [
    LegalSection(
      heading: '1. Introduction',
      body:
          'This Privacy Policy explains how $companyName ("we", "us") collects, '
          'uses, and protects your information when you use our application and '
          'services (the "Service"). By using $companyName, you agree to the '
          'practices described here.',
    ),
    LegalSection(
      heading: '2. Information We Collect',
      body:
          'Account information: your name, email address, and authentication '
          'details. Profile and coaching content: information you provide such as '
          'your mindset assessment, goals, habits, affirmations, journal entries, '
          'and your conversations with the coach. Usage information: app activity, '
          'streaks, and device information used to operate and improve the '
          'Service.',
    ),
    LegalSection(
      heading: '3. How We Use Your Information',
      body:
          'We use your information to provide and personalize the Service, '
          'generate AI coaching responses, track your progress, maintain your '
          'account, provide support, and improve the app. We do not sell your '
          'personal information.',
    ),
    LegalSection(
      heading: '4. AI Processing',
      body:
          'To generate personalized coaching, relevant portions of your profile '
          'and messages are sent through our secure backend to our AI provider '
          '(Anthropic) for processing. This content is used to produce responses '
          'for you and is not used to publicly identify you. We send only what is '
          'needed to provide the feature.',
    ),
    LegalSection(
      heading: '5. Storage and Processing',
      body:
          'Your data is stored and processed using Google Firebase services '
          '(including Firestore and Cloud Functions). These providers maintain '
          'their own security and privacy practices. Data may be processed in the '
          'United States.',
    ),
    LegalSection(
      heading: '6. Third-Party Services',
      body:
          'We rely on trusted third parties to operate the Service, including '
          'Google Firebase (authentication, database, cloud functions, and App '
          'Check / Google reCAPTCHA for abuse prevention on the web), Anthropic '
          '(AI model processing), RevenueCat (subscription management), and '
          'Mixpanel (product analytics). Their handling of data is governed by '
          'their own privacy policies.',
    ),
    LegalSection(
      heading: '7. Cookies, Analytics, and Similar Technologies',
      body:
          'We use cookies and similar technologies (such as local storage) to '
          'operate the Service. Essential technologies keep you signed in and '
          'secure your session, and Google reCAPTCHA helps protect the web app '
          'from abuse; these are necessary for the Service to function. With '
          'your consent, we also use Mixpanel analytics cookies to understand '
          'how the app is used so we can improve it. On the web you can accept '
          'or decline non-essential analytics cookies in the consent banner, '
          'and declining does not affect access to the Service. Your use of '
          'reCAPTCHA is also subject to Google\'s Privacy Policy and Terms of '
          'Service.',
    ),
    LegalSection(
      heading: '8. Data Retention and Deletion',
      body:
          'We retain your information for as long as your account is active. You '
          'can delete your account at any time from the in-app settings, which '
          'removes your profile and associated data from our active systems. Some '
          'information may persist in backups for a limited period or where '
          'retention is required by law.',
    ),
    LegalSection(
      heading: '9. Security',
      body:
          'We use reasonable technical and organizational measures to protect your '
          'information. However, no method of transmission or storage is '
          'completely secure, and we cannot guarantee absolute security.',
    ),
    LegalSection(
      heading: '10. Children',
      body:
          'The Service is not directed to children under 18, and we do not '
          'knowingly collect personal information from them. If you believe a '
          'child has provided us information, contact us so we can remove it.',
    ),
    LegalSection(
      heading: '11. Your Rights',
      body:
          'Depending on where you live, you may have rights to access, correct, '
          'delete, or export your personal information, and to object to or '
          'restrict certain processing. To exercise these rights, contact us at '
          '$contactEmail.',
    ),
    LegalSection(
      heading: '12. Changes to This Policy',
      body:
          'We may update this Privacy Policy from time to time. If we make '
          'material changes, we will provide notice within the Service or by other '
          'reasonable means. The effective date above reflects the latest '
          'revision.',
    ),
    LegalSection(
      heading: '13. Contact Us',
      body:
          'Questions about your privacy or this policy? Contact us at '
          '$contactEmail.',
    ),
  ];
}
