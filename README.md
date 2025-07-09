# Fanla Flutter Application

Fanla is a mobile application for football fans to explore teams, listen to chants, and follow matches.

## Features

- Country listing and selection
- Team listing by country
- Integration with Fanla API
- Environment configuration for development, mobile, and production

## Environment Configuration

The application supports three environments:

1. **Development (dev)**: Uses `http://localhost:8080` as the base URL
2. **Mobile (mobile)**: Uses `http://10.0.2.2:8080` for Android emulator testing
3. **Production (prod)**: Uses `https://api.fanla.com` for production

To change the environment, modify the `main.dart` file:

```dart
void main() {
  // Set the environment based on your needs
  // Options: Environment.dev, Environment.mobile, Environment.prod
  EnvironmentConfig.setEnvironment(Environment.dev);
  
  runApp(const MyApp());
}
```

## API Integration

The application integrates with the following Fanla API endpoints:

- `/api/fan/countries` - Get all countries
- `/api/fan/countries/{id}` - Get country by ID
- `/api/fan/teams` - Get all teams
- `/api/fan/teams/{id}` - Get team by ID
- `/api/fan/countries/{countryId}/teams` - Get teams by country

## Project Structure

- `lib/config` - Environment configuration
- `lib/models` - Data models (Country, Team)
- `lib/providers` - API providers
- `lib/screens` - UI screens
- `lib/utils` - Utility classes
