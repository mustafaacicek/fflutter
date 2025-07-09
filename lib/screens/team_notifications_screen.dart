import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team.dart';
import '../providers/api_provider.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../l10n/app_localizations.dart';

class TeamNotificationsScreen extends StatefulWidget {
  const TeamNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<TeamNotificationsScreen> createState() => _TeamNotificationsScreenState();
}

class _TeamNotificationsScreenState extends State<TeamNotificationsScreen> {
  bool _isLoading = true;
  List<Team> _allTeams = [];
  List<int> _subscribedTeamIds = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Tüm takımları yükle
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      final response = await apiProvider.getAllTeams();

      // Abone olunan takım ID'lerini al
      final subscribedIds = await NotificationService.getSubscribedTeamIds();

      if (mounted) {
        setState(() {
          if (response.success && response.data != null) {
            _allTeams = response.data!;
            _subscribedTeamIds = subscribedIds;
            _isLoading = false;
          } else {
            _isLoading = false;
            _errorMessage = response.error ?? AppLocalizations.of(context).errorLoadingTeams;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _toggleTeamSubscription(Team team) async {
    final isSubscribed = _subscribedTeamIds.contains(team.id);

    setState(() {
      // UI'ı hemen güncelle
      if (isSubscribed) {
        _subscribedTeamIds.remove(team.id);
      } else {
        _subscribedTeamIds.add(team.id);
      }
    });

    try {
      if (isSubscribed) {
        // Aboneliği kaldır
        await NotificationService.unsubscribeFromTeam(team);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${team.name} takımının bildirimlerini almayı durdurdunuz'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Abone ol
        await NotificationService.subscribeToTeam(team);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${team.name} takımının bildirimlerini almaya başladınız'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Hata durumunda UI'ı eski haline getir
      setState(() {
        if (isSubscribed) {
          _subscribedTeamIds.add(team.id);
        } else {
          _subscribedTeamIds.remove(team.id);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Takım Bildirimleri',
          style: TextStyle(
            color: AppTheme.textColorOnPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: IconThemeData(color: AppTheme.textColorOnPrimary),
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _errorMessage != null
              ? _buildErrorMessage()
              : _buildTeamsList(),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textColorOnPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Bildirim almak istediğiniz takımları seçin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _allTeams.length,
            itemBuilder: (context, index) {
              final team = _allTeams[index];
              final isSubscribed = _subscribedTeamIds.contains(team.id);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: team.logoUrl.isNotEmpty
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(team.logoUrl),
                          backgroundColor: Colors.transparent,
                        )
                      : CircleAvatar(
                          child: Text(team.name[0]),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                  title: Text(
                    team.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(team.countryName),
                  trailing: Switch(
                    value: isSubscribed,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) => _toggleTeamSubscription(team),
                  ),
                  onTap: () => _toggleTeamSubscription(team),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
