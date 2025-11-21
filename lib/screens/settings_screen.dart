import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../services/storage_service.dart';
import '../services/scraping_service.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF0d0d0d),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1a1a1a),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Location Section
              _buildSectionTitle('Location'),
              _buildSettingsTile(
                icon: Icons.location_on,
                title: 'Selected Location',
                subtitle: appState.selectedCountry != null && appState.selectedCity != null
                    ? '${appState.selectedCity!.name}, ${appState.selectedCountry!.name}'
                    : 'No location selected',
                onTap: () {
                  _showChangeLocationDialog(context);
                },
              ),
              
              const SizedBox(height: 24),
              
              // Data Section
              _buildSectionTitle('Data & Storage'),
              _buildSettingsTile(
                icon: Icons.favorite,
                title: 'Favorite Stations',
                subtitle: '${appState.favoriteStations.length} stations',
              ),
              _buildSettingsTile(
                icon: Icons.history,
                title: 'Recent Stations',
                subtitle: '${appState.lastPlayedStations.length} stations',
              ),
              _buildSettingsTile(
                icon: Icons.refresh,
                title: 'Clear Cache',
                subtitle: 'Clear cached station data',
                onTap: () {
                  _showClearCacheDialog(context);
                },
              ),
              _buildSettingsTile(
                icon: Icons.delete_forever,
                title: 'Clear All Data',
                subtitle: 'Reset app to initial state',
                onTap: () {
                  _showClearAllDataDialog(context);
                },
              ),
              
              const SizedBox(height: 24),
              
              // About Section
              _buildSectionTitle('About'),
              _buildSettingsTile(
                icon: Icons.info,
                title: 'App Version',
                subtitle: '1.02',
              ),
              _buildSettingsTile(
                icon: Icons.radio,
                title: 'About Radiofy',
                subtitle: 'Stream radio stations from around the world',
              ),
              _buildSettingsTile(
                icon: Icons.favorite,
                title: 'Donate',
                subtitle: 'Support Radiofy development',
                onTap: () {
                  _openDonationLink();
                },
              ),
              
              const SizedBox(height: 32),
              
              // Footer
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: const DecorationImage(
                          image: AssetImage('assets/radiofylogo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Radiofy',
                      style: TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'World Radio at Your Fingertips',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFF6B35),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF6B35),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        trailing: trailing ?? (onTap != null 
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : null),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showChangeLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Change Location',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will take you back to the location selection screen. Your current settings will be preserved.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const SetupScreen(),
                ),
              );
            },
            child: const Text(
              'Change',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Clear Cache',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will clear cached station data. The app will need to reload stations from the internet.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              ScrapingService.clearCache();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Color(0xFFFF6B35),
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Clear All Data',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete all your favorites, recent stations, and settings. This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _isClearing = true;
              });
              
              try {
                await StorageService.clearAllData();
                ScrapingService.clearCache();
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const SetupScreen(),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                setState(() {
                  _isClearing = false;
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing data: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: _isClearing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Clear All',
                    style: TextStyle(color: Colors.red),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDonationLink() async {
    const url = 'https://www.paypal.com/donate/?business=6PNHFW2AUEJLE&no_recurring=0&item_name=Keep+Radiofy+alive%21&currency_code=BRL';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open donation link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening donation link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}