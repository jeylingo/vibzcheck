import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const clientId = 'f5928f1551e54156a1cdf3d463885a04';
  const clientSecret = 'f4521e249f5446c9adf96520d137a6dc';

  final tokenRes = await http.post(
    Uri.parse('https://accounts.spotify.com/api/token'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {
      'grant_type': 'client_credentials',
      'client_id': clientId,
      'client_secret': clientSecret,
    },
  );

  final token = jsonDecode(tokenRes.body)['access_token'];

  final query = 'Praise';
  final encodedQuery = Uri.encodeComponent(query);
  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/search?q=' + encodedQuery + '&type=track&limit=10'),
    headers: {'Authorization': 'Bearer ' + token},
  );

  print('Status: ' + response.statusCode.toString());
  print('Body: ' + response.body);
}
