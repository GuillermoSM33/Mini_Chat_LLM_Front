//En esta clase definimos el modelo de datos para los mensajes
//intercambiados entre el usuario y el asistente
class Message {
  final String role; // usuario o asistente
  final String content; // contenido del mensaje

  //El mensaje se crea con un rol y contenido obligatorios
  Message({required this.role, required this.content});

  //Convierte el mensaje a formato JSON para enviarlo al backend
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
  
  //El factory permite crear una instancia de Message a partir de un JSON y devuelve un objeto Message
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'],
      content: json['content'],
    );
  }
}
