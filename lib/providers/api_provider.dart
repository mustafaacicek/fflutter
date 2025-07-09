import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../models/country.dart';
import '../models/match.dart';
import '../models/sound.dart';
import '../models/team.dart';
import '../models/lyrics.dart';
import '../utils/api_utils.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ApiProvider {
  final String _baseUrl = EnvironmentConfig.apiUrl;

  // Local storage file paths
  Future<String> get _countriesFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/countries.json';
  }

  Future<String> _teamsFilePath(int countryId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/teams_$countryId.json';
  }

  Future<String> get _allTeamsFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/all_teams.json';
  }

  // Image cache directory
  Future<Directory> get _imagesCacheDir async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  // Get local image path for a URL
  Future<String> _getLocalImagePath(String url) async {
    final imagesDir = await _imagesCacheDir;
    // Create a filename from the URL (using hash to avoid invalid characters)
    final filename = url.hashCode.toString();
    return '${imagesDir.path}/$filename.jpg';
  }

  // Check if an image is cached locally
  Future<bool> isImageCached(String url) async {
    final localPath = await _getLocalImagePath(url);
    return File(localPath).exists();
  }

  // Custom cache manager for images
  static final customCacheManager = CacheManager(
    Config(
      'imagesCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  );

  // Save countries to local storage
  Future<void> _saveCountriesToLocal(List<Country> countries) async {
    try {
      final file = File(await _countriesFilePath);
      final data = jsonEncode(
        countries.map((country) => country.toJson()).toList(),
      );
      await file.writeAsString(data);
      print('Countries saved to local storage: ${countries.length} countries');

      // Download and cache country logos
      for (final country in countries) {
        await cacheImageFromUrl(country.logoUrl);
      }
    } catch (e) {
      print('Error saving countries to local storage: $e');
    }
  }

  // Load countries from local storage
  Future<List<Country>?> _loadCountriesFromLocal() async {
    try {
      final file = File(await _countriesFilePath);
      if (await file.exists()) {
        final data = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(data);
        final countries = jsonData
            .map((json) => Country.fromJson(json))
            .toList();
        print('Loaded ${countries.length} countries from local storage');
        return countries;
      }
    } catch (e) {
      print('Error loading countries from local storage: $e');
    }
    return null;
  }

  // Save teams to local storage by country
  Future<void> _saveTeamsByCountryToLocal(
    List<Team> teams,
    int countryId,
  ) async {
    try {
      final file = File(await _teamsFilePath(countryId));
      final data = jsonEncode(teams.map((team) => team.toJson()).toList());
      await file.writeAsString(data);
      print(
        'Teams for country $countryId saved to local storage: ${teams.length} teams',
      );

      // Download and cache team logos
      for (final team in teams) {
        await cacheImageFromUrl(team.logoUrl);
      }
    } catch (e) {
      print('Error saving teams to local storage: $e');
    }
  }

  // Load teams from local storage by country
  Future<List<Team>?> _loadTeamsByCountryFromLocal(int countryId) async {
    try {
      final file = File(await _teamsFilePath(countryId));
      if (await file.exists()) {
        final data = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(data);
        final teams = jsonData.map((json) => Team.fromJson(json)).toList();
        print(
          'Loaded ${teams.length} teams for country $countryId from local storage',
        );
        return teams;
      }
    } catch (e) {
      print('Error loading teams from local storage: $e');
    }
    return null;
  }

  // Save all teams to local storage
  Future<void> _saveAllTeamsToLocal(List<Team> teams) async {
    try {
      final file = File(await _allTeamsFilePath);
      final data = jsonEncode(teams.map((team) => team.toJson()).toList());
      await file.writeAsString(data);
      print('All teams saved to local storage: ${teams.length} teams');

      // Download and cache team logos
      for (final team in teams) {
        await cacheImageFromUrl(team.logoUrl);
      }
    } catch (e) {
      print('Error saving all teams to local storage: $e');
    }
  }

  // Cache image from URL
  Future<String?> cacheImageFromUrl(String url) async {
    try {
      // Skip if URL is empty or invalid
      if (url.isEmpty || !url.startsWith('http')) {
        return null;
      }

      final localPath = await _getLocalImagePath(url);
      final file = File(localPath);

      // Check if file already exists
      if (await file.exists()) {
        // File exists, check if it's not too old (7 days)
        final fileStats = await file.stat();
        final fileAge = DateTime.now().difference(fileStats.modified);
        if (fileAge.inDays < 7) {
          return localPath; // Return existing file if not too old
        }
      }

      // Download image
      print('Downloading image: $url');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Save to file
        await file.writeAsBytes(response.bodyBytes);
        print('Image cached: $url');
        return localPath;
      } else {
        print('Failed to download image: $url (${response.statusCode})');
        return null;
      }
    } catch (e) {
      print('Error caching image $url: $e');
      return null;
    }
  }

  // Get image provider for a URL (with local caching)
  Future<ImageProvider> getImageProvider(String url) async {
    try {
      // Try to get from local cache first
      final localPath = await _getLocalImagePath(url);
      final file = File(localPath);

      if (await file.exists()) {
        // Use local file
        return FileImage(file);
      } else {
        // Cache the image for future use
        cacheImageFromUrl(url); // Don't await, let it cache in background

        // Use network image for now
        return NetworkImage(url);
      }
    } catch (e) {
      print('Error getting image provider for $url: $e');
      return NetworkImage(url); // Fallback to network image
    }
  }

  // Load all teams from local storage
  Future<List<Team>?> _loadAllTeamsFromLocal() async {
    try {
      final file = File(await _allTeamsFilePath);
      if (await file.exists()) {
        final data = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(data);
        final teams = jsonData.map((json) => Team.fromJson(json)).toList();
        print('Loaded ${teams.length} teams from local storage');
        return teams;
      }
    } catch (e) {
      print('Error loading all teams from local storage: $e');
    }
    return null;
  }

  // Countries API
  // Get a cached image file for a URL
  Future<File?> getCachedImageFile(String url) async {
    try {
      final localPath = await _getLocalImagePath(url);
      final file = File(localPath);

      if (await file.exists()) {
        return file;
      }

      // If not cached, try to download and cache
      final cachedPath = await cacheImageFromUrl(url);
      if (cachedPath != null) {
        return File(cachedPath);
      }

      return null;
    } catch (e) {
      print('Error getting cached image file for $url: $e');
      return null;
    }
  }

  Future<ApiResponse<List<Country>>> getCountries() async {
    try {
      // First try to load from local storage
      final localCountries = await _loadCountriesFromLocal();
      if (localCountries != null && localCountries.isNotEmpty) {
        print('Using ${localCountries.length} countries from local storage');

        // Fetch from API in background to update local cache
        _fetchAndUpdateCountries();

        return ApiResponse.success(localCountries);
      }

      // If not in local storage, fetch from API
      return await _fetchAndUpdateCountries();
    } catch (e) {
      print('Error in getCountries: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Fetch countries from API and update local storage
  Future<ApiResponse<List<Country>>> _fetchAndUpdateCountries() async {
    try {
      print('Fetching countries from: $_baseUrl/countries');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/countries'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Country> countries = (data as List)
          .map((json) => Country.fromJson(json))
          .toList();

      // Save to local storage
      await _saveCountriesToLocal(countries);

      return ApiResponse.success(countries);
    } catch (e) {
      print('Error fetching countries: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  Future<ApiResponse<Country>> getCountryById(int id) async {
    try {
      // First try to load all countries from local storage
      final localCountries = await _loadCountriesFromLocal();
      if (localCountries != null && localCountries.isNotEmpty) {
        // Find the country with the given id
        final country = localCountries.firstWhere(
          (country) => country.id == id,
          orElse: () => throw Exception('Country not found in local storage'),
        );
        print('Using country $id from local storage');

        // Fetch from API in background to ensure data is up to date
        _fetchCountryByIdFromApi(id);

        return ApiResponse.success(country);
      }

      // If not in local storage, fetch from API
      return await _fetchCountryByIdFromApi(id);
    } catch (e) {
      print('Error in getCountryById: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Fetch country by id from API
  Future<ApiResponse<Country>> _fetchCountryByIdFromApi(int id) async {
    try {
      print('Fetching country by id from: $_baseUrl/countries/$id');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/countries/$id'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');

      final dynamic data = ApiUtils.parseResponse(response);
      final Country country = Country.fromJson(data);

      // Update country in local storage
      final localCountries = await _loadCountriesFromLocal() ?? [];
      final updatedCountries = List<Country>.from(localCountries);

      // Replace or add the country
      final index = updatedCountries.indexWhere((c) => c.id == id);
      if (index != -1) {
        updatedCountries[index] = country;
      } else {
        updatedCountries.add(country);
      }

      await _saveCountriesToLocal(updatedCountries);

      return ApiResponse.success(country);
    } catch (e) {
      print('Error fetching country by id: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Teams API
  Future<ApiResponse<List<Team>>> getAllTeams() async {
    try {
      // First try to load from local storage
      final localTeams = await _loadAllTeamsFromLocal();
      if (localTeams != null && localTeams.isNotEmpty) {
        print('Using ${localTeams.length} teams from local storage');

        // Fetch from API in background to update local cache
        _fetchAndUpdateAllTeams();

        return ApiResponse.success(localTeams);
      }

      // If not in local storage, fetch from API
      return await _fetchAndUpdateAllTeams();
    } catch (e) {
      print('Error in getAllTeams: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Fetch all teams from API and update local storage
  Future<ApiResponse<List<Team>>> _fetchAndUpdateAllTeams() async {
    try {
      print('Fetching all teams from: $_baseUrl/teams');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/teams'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Team> teams = (data as List)
          .map((json) => Team.fromJson(json))
          .toList();

      // Save to local storage
      await _saveAllTeamsToLocal(teams);

      return ApiResponse.success(teams);
    } catch (e) {
      print('Error fetching all teams: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  Future<ApiResponse<Team>> getTeamById(int id) async {
    try {
      // First try to load all teams from local storage
      final localTeams = await _loadAllTeamsFromLocal();
      if (localTeams != null && localTeams.isNotEmpty) {
        // Find the team with the given id
        final teamIndex = localTeams.indexWhere((team) => team.id == id);
        if (teamIndex != -1) {
          print('Using team $id from local storage');

          // Fetch from API in background to ensure data is up to date
          _fetchTeamByIdFromApi(id);

          return ApiResponse.success(localTeams[teamIndex]);
        }
      }

      // If not in local storage, fetch from API
      return await _fetchTeamByIdFromApi(id);
    } catch (e) {
      print('Error in getTeamById: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Fetch team by id from API
  Future<ApiResponse<Team>> _fetchTeamByIdFromApi(int id) async {
    try {
      print('Fetching team by id from: $_baseUrl/teams/$id');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/teams/$id'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');

      final dynamic data = ApiUtils.parseResponse(response);
      final Team team = Team.fromJson(data);

      // Update team in local storage
      final localTeams = await _loadAllTeamsFromLocal() ?? [];
      final updatedTeams = List<Team>.from(localTeams);

      // Replace or add the team
      final index = updatedTeams.indexWhere((t) => t.id == id);
      if (index != -1) {
        updatedTeams[index] = team;
      } else {
        updatedTeams.add(team);
      }

      await _saveAllTeamsToLocal(updatedTeams);

      return ApiResponse.success(team);
    } catch (e) {
      print('Error fetching team by id: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  Future<ApiResponse<List<Team>>> getTeamsByCountry(int countryId) async {
    try {
      // First try to load from local storage
      final localTeams = await _loadTeamsByCountryFromLocal(countryId);
      if (localTeams != null && localTeams.isNotEmpty) {
        print(
          'Using ${localTeams.length} teams for country $countryId from local storage',
        );

        // Fetch from API in background to update local cache
        _fetchAndUpdateTeamsByCountry(countryId);

        return ApiResponse.success(localTeams);
      }

      // If not in local storage, fetch from API
      return await _fetchAndUpdateTeamsByCountry(countryId);
    } catch (e) {
      print('Error in getTeamsByCountry: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Fetch teams by country from API and update local storage
  Future<ApiResponse<List<Team>>> _fetchAndUpdateTeamsByCountry(
    int countryId,
  ) async {
    try {
      print(
        'Fetching teams by country from: $_baseUrl/countries/$countryId/teams',
      );
      final response = await http
          .get(
            Uri.parse('$_baseUrl/countries/$countryId/teams'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Team> teams = (data as List)
          .map((json) => Team.fromJson(json))
          .toList();

      // Save to local storage
      await _saveTeamsByCountryToLocal(teams, countryId);

      // Also update the all teams cache if it exists
      final allTeams = await _loadAllTeamsFromLocal();
      if (allTeams != null) {
        final updatedAllTeams = List<Team>.from(allTeams);

        // Remove existing teams for this country and add new ones
        updatedAllTeams.removeWhere((team) => team.countryId == countryId);
        updatedAllTeams.addAll(teams);

        await _saveAllTeamsToLocal(updatedAllTeams);
      }

      return ApiResponse.success(teams);
    } catch (e) {
      print('Error fetching teams by country: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Matches API
  Future<ApiResponse<List<Match>>> getMatchesByTeam(int teamId) async {
    try {
      print(
        'Fetching matches by team from: $_baseUrl/teams/$teamId/matches',
      ); // Debug log
      final response = await http
          .get(
            Uri.parse('$_baseUrl/teams/$teamId/matches'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}'); // Debug log

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Match> matches = (data as List)
          .map((json) => Match.fromJson(json))
          .toList();

      return ApiResponse.success(matches);
    } catch (e) {
      print('Error fetching matches by team: $e'); // Debug log
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Sounds API
  Future<ApiResponse<List<Sound>>> getSoundsByTeam(int teamId) async {
    try {
      print(
        'Fetching sounds by team from: $_baseUrl/teams/$teamId/sounds',
      ); // Debug log
      final response = await http
          .get(
            Uri.parse('$_baseUrl/teams/$teamId/sounds'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}'); // Debug log

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Sound> sounds = (data as List)
          .map((json) => Sound.fromJson(json))
          .toList();

      // Update download status from local storage
      await _updateSoundsDownloadStatus(sounds, teamId);

      return ApiResponse.success(sounds);
    } catch (e) {
      print('Error fetching sounds by team: $e'); // Debug log
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Check and update download status for sounds from server
  Future<ApiResponse<List<Sound>>> checkSoundDownloadStatus(
    int teamId,
    Map<int, bool> downloadStatus,
  ) async {
    try {
      print('Checking sound download status for team: $teamId'); // Debug log

      // Convert Map<int, bool> to Map<String, bool> for JSON serialization
      final Map<String, bool> statusMap = {};
      downloadStatus.forEach((key, value) {
        statusMap[key.toString()] = value;
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/teams/$teamId/sounds/check-download-status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'downloadStatus': statusMap}),
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}'); // Debug log

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Sound> sounds = (data as List)
          .map((json) => Sound.fromJson(json))
          .toList();

      return ApiResponse.success(sounds);
    } catch (e) {
      print('Error checking sound download status: $e'); // Debug log
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Local Storage Management for Sounds
  Future<void> _updateSoundsDownloadStatus(
    List<Sound> sounds,
    int teamId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedSoundsJson = prefs.getString('team_${teamId}_sounds');

    if (storedSoundsJson != null) {
      final List<dynamic> storedSounds = jsonDecode(storedSoundsJson);
      final Map<int, bool> downloadStatus = {};

      for (var soundJson in storedSounds) {
        final Sound sound = Sound.fromJson(soundJson);
        downloadStatus[sound.id] = sound.isDownloaded;
      }

      // Update current sounds with stored download status
      for (var sound in sounds) {
        if (downloadStatus.containsKey(sound.id)) {
          sound.isDownloaded = downloadStatus[sound.id]!;
        }
      }
    }
  }

  // Save team sounds to local storage
  Future<void> saveTeamSounds(List<Sound> sounds, int teamId) async {
    final prefs = await SharedPreferences.getInstance();

    // Save the current team ID
    await prefs.setInt('current_team_id', teamId);

    // Save the sounds list
    final List<Map<String, dynamic>> soundsJson = sounds
        .map((s) => s.toJson())
        .toList();
    await prefs.setString('team_${teamId}_sounds', jsonEncode(soundsJson));

    print('Saved ${sounds.length} sounds for team $teamId to local storage');
  }

  // Get current team ID from local storage
  Future<int?> getCurrentTeamId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('current_team_id');
  }

  // Get stored sounds for a team from local storage
  Future<List<Sound>> getStoredSounds(int teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedSoundsJson = prefs.getString('team_${teamId}_sounds');

    if (storedSoundsJson != null) {
      final List<dynamic> storedSounds = jsonDecode(storedSoundsJson);
      return storedSounds.map((json) => Sound.fromJson(json)).toList();
    }

    return [];
  }

  // Clear sounds for a team from local storage
  Future<void> clearTeamSounds(int teamId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('team_${teamId}_sounds');
    print('Cleared sounds for team $teamId from local storage');
  }

  // Update download status for a specific sound
  Future<void> updateSoundDownloadStatus(
    int teamId,
    int soundId,
    bool isDownloaded,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final soundsJson = prefs.getString('team_${teamId}_sounds');

    if (soundsJson != null) {
      final List<dynamic> decodedSounds = jsonDecode(soundsJson);
      final List<Sound> storedSounds = decodedSounds
          .map((json) => Sound.fromJson(json))
          .toList();

      // Find the sound and update its download status
      for (var i = 0; i < storedSounds.length; i++) {
        if (storedSounds[i].id == soundId) {
          // Create a new sound object with updated download status
          final updatedSound = Sound(
            id: storedSounds[i].id,
            title: storedSounds[i].title,
            soundUrl: storedSounds[i].soundUrl,
            soundImageUrl: storedSounds[i].soundImageUrl,
            teamId: storedSounds[i].teamId,
            teamName: storedSounds[i].teamName,
            status: storedSounds[i].status,
            currentMillisecond: storedSounds[i].currentMillisecond,
            updatedAt: storedSounds[i].updatedAt,
            isDownloaded: isDownloaded,
          );
          storedSounds[i] = updatedSound;
        }
      }

      // Save updated sounds back to storage
      final List<Map<String, dynamic>> updatedSoundsJson = storedSounds
          .map((s) => s.toJson())
          .toList();
      await prefs.setString(
        'team_${teamId}_sounds',
        jsonEncode(updatedSoundsJson),
      );

      print('Updated download status for sound $soundId to $isDownloaded');
    }
  }

  // Update the decode status of a sound in shared preferences
  Future<void> updateSoundDecodeStatus(
    int teamId,
    int soundId,
    bool isDecoded,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Get the current decode status map or create a new one
    final String? decodedSoundsJson = prefs.getString(
      'team_${teamId}_decoded_sounds',
    );
    Map<String, dynamic> decodedSounds = {};

    if (decodedSoundsJson != null) {
      decodedSounds = jsonDecode(decodedSoundsJson);
    }

    // Update the decode status for this sound
    decodedSounds['sound_$soundId'] = isDecoded;

    // Save back to shared preferences
    await prefs.setString(
      'team_${teamId}_decoded_sounds',
      jsonEncode(decodedSounds),
    );

    print('Updated decode status for sound $soundId to $isDecoded');
  }

  // Check if a sound is already decoded
  Future<bool> isSoundDecoded(int teamId, int soundId) async {
    final prefs = await SharedPreferences.getInstance();

    // Get the current decode status map
    final String? decodedSoundsJson = prefs.getString(
      'team_${teamId}_decoded_sounds',
    );

    if (decodedSoundsJson != null) {
      final Map<String, dynamic> decodedSounds = jsonDecode(decodedSoundsJson);
      return decodedSounds['sound_$soundId'] == true;
    }

    return false;
  }

  Future<ApiResponse<List<Match>>> getUpcomingMatchesByTeam(int teamId) async {
    try {
      print(
        'Fetching upcoming matches by team from: $_baseUrl/teams/$teamId/matches/upcoming',
      ); // Debug log
      final response = await http
          .get(
            Uri.parse('$_baseUrl/teams/$teamId/matches/upcoming'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}'); // Debug log

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Match> matches = (data as List)
          .map((json) => Match.fromJson(json))
          .toList();

      return ApiResponse.success(matches);
    } catch (e) {
      print('Error fetching upcoming matches by team: $e'); // Debug log
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  Future<ApiResponse<List<Match>>> getPastMatchesByTeam(int teamId) async {
    try {
      print(
        'Fetching past matches by team from: $_baseUrl/teams/$teamId/matches/past',
      ); // Debug log
      final response = await http
          .get(
            Uri.parse('$_baseUrl/teams/$teamId/matches/past'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}'); // Debug log

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Match> matches = (data as List)
          .map((json) => Match.fromJson(json))
          .toList();

      return ApiResponse.success(matches);
    } catch (e) {
      print('Error fetching past matches by team: $e'); // Debug log
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Fetch the current sound state for a match
  Future<Map<String, dynamic>?> fetchMatchSoundState(int matchId) async {
    try {
      print(
        'Fetching sound state for match from: $_baseUrl/matches/$matchId/sound-state',
      ); // Debug log
      final response = await http
          .get(
            Uri.parse('$_baseUrl/matches/$matchId/sound-state'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}'); // Debug log

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        // No active sound for this match
        print('No active sound for match $matchId');
        return null;
      } else {
        throw Exception('Failed to fetch sound state: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching match sound state: $e'); // Debug log
      return null;
    }
  }

  // Get active sound for a match with current state
  Future<Map<String, dynamic>?> getActiveMatchSound(int matchId) async {
    try {
      print('Getting active sound for match $matchId');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/matches/$matchId/active-sound'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        print(
          'No active sound for match $matchId or error: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('Error getting active match sound: $e');
      return null;
    }
  }
  
  // Get teams from API
  Future<ApiResponse<List<Team>>> getTeams() async {
    try {
      print('Fetching teams from API');
      
      // First try to load from local storage
      final localTeams = await _loadAllTeamsFromLocal();
      if (localTeams != null && localTeams.isNotEmpty) {
        print('Loaded ${localTeams.length} teams from local storage');
        return ApiResponse.success(localTeams);
      }
      
      // If not available locally, fetch from API
      final response = await http
          .get(
            Uri.parse('$_baseUrl/teams'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');

      final dynamic data = ApiUtils.parseResponse(response);
      final List<Team> teams = (data as List)
          .map((json) => Team.fromJson(json))
          .toList();
      
      // Save to local storage for future use
      await _saveAllTeamsToLocal(teams);
      
      return ApiResponse.success(teams);
    } catch (e) {
      print('Error fetching teams: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }
  
  // Get specific match by ID
  Future<ApiResponse<Match>> getMatch(int matchId) async {
    try {
      print('Fetching match $matchId from API');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/matches/$matchId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');

      final dynamic data = ApiUtils.parseResponse(response);
      final Match match = Match.fromJson(data);
      
      return ApiResponse.success(match);
    } catch (e) {
      print('Error fetching match: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }

  // Get lyrics for a specific sound with proper authorization
  Future<ApiResponse<List<Lyrics>>> getSoundLyrics(
    int teamId,
    int soundId,
  ) async {
    try {
      print(
        'Fetching lyrics for sound $soundId from: $_baseUrl/api/fan/teams/$teamId/sounds/$soundId/lyrics',
      );

      // Get the auth token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final String? authToken = prefs.getString('auth_token');
      if (authToken == null) {
        print('Error: No auth token available');
        return ApiResponse.error('Authentication token not found');
      }

      // Make the API call with authorization header
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/fan/teams/$teamId/sounds/$soundId/lyrics'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(Duration(seconds: EnvironmentConfig.timeoutSeconds));

      print('Response status: ${response.statusCode}');
      final dynamic data = ApiUtils.parseResponse(response);
      final List<Lyrics> lyrics = (data as List)
          .map((json) => Lyrics.fromJson(json))
          .toList();

      return ApiResponse.success(lyrics);
    } catch (e) {
      print('Error fetching lyrics: $e');
      return ApiResponse.error(ApiUtils.handleError(e));
    }
  }
}
