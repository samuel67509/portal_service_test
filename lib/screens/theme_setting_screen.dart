import 'package:flutter/material.dart';
import 'package:portal_service_test/theme/theme_provider.dart';
import 'package:provider/provider.dart';



class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Theme Settings'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleDarkMode(),
            tooltip: 'Toggle dark mode',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dark Mode Toggle
            Card(
              child: SwitchListTile(
                title: Text('Dark Mode'),
                subtitle: Text('Switch between light and dark theme'),
                value: isDarkMode,
                onChanged: (value) => themeProvider.toggleDarkMode(),
                secondary: Icon(isDarkMode ? Icons.nightlight : Icons.wb_sunny),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Color Themes
            Text('Color Themes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildThemeOption(
                  context,
                  'Light',
                  Colors.deepPurple,
                  'light',
                  isDarkMode ? Icons.light_mode_outlined : Icons.light_mode,
                ),
                _buildThemeOption(
                  context,
                  'Dark',
                  Colors.grey[800]!,
                  'dark',
                  Icons.dark_mode,
                ),
                _buildThemeOption(
                  context,
                  'Blue',
                  Colors.blue,
                  'blue',
                  Icons.water_drop,
                ),
                _buildThemeOption(
                  context,
                  'Purple',
                  Colors.purple,
                  'purple',
                  Icons.brush,
                ),
                _buildThemeOption(
                  context,
                  'Green',
                  Colors.green,
                  'green',
                  Icons.nature,
                ),
              ],
            ),
            
            SizedBox(height: 30),
            
            // Role Themes Preview
            Text('Role Themes Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Column(
              children: [
                _buildRoleThemePreview('Admin', Colors.purple, Icons.admin_panel_settings),
                SizedBox(height: 8),
                _buildRoleThemePreview('Front Desk', Colors.blue, Icons.desk),
                SizedBox(height: 8),
                _buildRoleThemePreview('Elder', Colors.green, Icons.people),
              ],
            ),
            
            Spacer(),
            
            // Current Theme Info
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Icon(Icons.palette, color: Colors.white),
                ),
                title: Text('Current Theme'),
                subtitle: Text(themeProvider.currentTheme as String),
                trailing: Chip(
                  label: Text(isDarkMode ? 'Dark' : 'Light'),
                  backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThemeOption(BuildContext context, String label, Color color, String themeName, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSelected = themeProvider.currentTheme == themeName;
    
    return GestureDetector(
      onTap: () => themeProvider.setTheme(themeName),
      child: Container(
        width: 100,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoleThemePreview(String role, Color color, IconData icon) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(role),
        subtitle: Text('${role} interface colors'),
        trailing: Container(
          width: 40,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.5)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

