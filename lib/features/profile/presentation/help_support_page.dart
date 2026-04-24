import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqCard(),
          const SizedBox(height: 14),
          _buildSupportCard(context),
          const SizedBox(height: 14),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildFaqCard() {
    return _CardShell(
      title: 'FAQ',
      child: const Column(
        children: [
          ExpansionTile(
            title: Text('How do reminders work?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Enable reminders from Notifications and StudyFlow will schedule local alerts for tasks, classes, and daily study time.',
                ),
              ),
            ],
          ),
          Divider(height: 1),
          ExpansionTile(
            title: Text('Can I use StudyFlow offline?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Yes. Recent profile, tasks, and reminder settings stay available locally, and your account and tasks sync through Supabase when you are online.',
                ),
              ),
            ],
          ),
          Divider(height: 1),
          ExpansionTile(
            title: Text('How can I edit my profile?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Go to Profile > Edit Profile. Your name and email sync to your account, while avatar selection is still stored on this device.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    return _CardShell(
      title: 'Contact & Reporting',
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.support_agent),
            title: Text('Contact support'),
            subtitle: Text('support@studyflow.app (placeholder)'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report a problem'),
            subtitle: const Text('Send issue details to support team'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Issue reporting endpoint is not connected yet. This placeholder confirms the intended flow.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return _CardShell(
      title: 'App Version',
      child: const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('StudyFlow 1.0.0'),
        subtitle: Text(
          'Student productivity planner with Supabase sync',
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}
