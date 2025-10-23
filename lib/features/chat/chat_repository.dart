import '../../core/api_client.dart';
import '../../core/models.dart';

class ChatRepository {
  final ApiClient _apiClient = ApiClient();

  Future<String> ask(String message, List<Message> history) async {
    final response = await _apiClient.client.post(
      '/chat',
      data: {'message': message, 'history': history.map((m) => m.toJson()).toList()},
    );
    return response.data['answer'] ?? 'Sin respuesta del servidor.';
  }
}
