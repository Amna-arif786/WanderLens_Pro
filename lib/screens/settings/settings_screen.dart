import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wanderlens/services/theme_service.dart';
import 'package:wanderlens/services/user_service.dart';
import '../../responsive/constrained_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: Icon(themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              value: themeService.isDarkMode,
              onChanged: (bool value) => themeService.toggleTheme(value),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
            child: Text('Password & Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const Icon(Icons.security, color: Colors.orange),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showChangePasswordSheet(context),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
            child: Text('Support & About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                const ListTile(leading: Icon(Icons.info_outline), title: Text('Version'), trailing: Text('1.0.0')),
                ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Terms of Service'), onTap: () {}),
                ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy Policy'), onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => const PasswordSheetWidget(),
    );
  }
}

class PasswordSheetWidget extends StatefulWidget {
  const PasswordSheetWidget({super.key});

  @override
  State<PasswordSheetWidget> createState() => _PasswordSheetWidgetState();
}

class _PasswordSheetWidgetState extends State<PasswordSheetWidget> {
  final _formKey = GlobalKey<FormState>();
  final _curP = TextEditingController();
  final _newP = TextEditingController();
  final _conP = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _curP.dispose(); _newP.dispose(); _conP.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _curP,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _newP,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.length < 8) ? 'Min 8 chars' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _conP,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
              validator: (v) => (v != _newP.text) ? 'Mismatch' : null,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _update,
                child: _loading ? const CircularProgressIndicator() : const Text('Update Password'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _update() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      try {
        await UserService.changePassword(_curP.text, _newP.text);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password Updated!'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }
}
