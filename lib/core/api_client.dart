import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  final Dio _dio;

//En esta parte se configura la URL base del backend para las peticiones HTTP
// y se establecen los tiempos de espera para las conexiones y recepciones de datos
  ApiClient() 
  //Inicializa el cliente Dio con las opciones base
      : _dio = Dio(BaseOptions(
          baseUrl: dotenv.env['BACKEND_BASE_URL'] ?? '', //Este configura la URL base que es leida desde las variables de entorno
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
            },
        ));

  //El Dio hace las peticiones HTTP
  Dio get client => _dio; 
}
