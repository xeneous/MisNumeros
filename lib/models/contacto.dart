class Contacto {
  final int idContacto;
  final String
  userId; // Changed from int idUsuario to String userId (Firebase UID)
  final String nombre;
  final String? email;
  final String? telefono;
  final String? banco;
  final String? cuentaDestino;
  final String? notas;
  final bool favorito;

  Contacto({
    required this.idContacto,
    required this.userId,
    required this.nombre,
    this.email,
    this.telefono,
    this.banco,
    this.cuentaDestino,
    this.notas,
    this.favorito = false,
  });

  Contacto copyWith({
    int? idContacto,
    String? userId,
    String? nombre,
    String? email,
    String? telefono,
    String? banco,
    String? cuentaDestino,
    String? notas,
    bool? favorito,
  }) {
    return Contacto(
      idContacto: idContacto ?? this.idContacto,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      banco: banco ?? this.banco,
      cuentaDestino: cuentaDestino ?? this.cuentaDestino,
      notas: notas ?? this.notas,
      favorito: favorito ?? this.favorito,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_contacto': idContacto,
      'user_id': userId, // Changed field name to user_id for consistency
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'banco': banco,
      'cuenta_destino': cuentaDestino,
      'notas': notas,
      'favorito': favorito ? 1 : 0,
    };
  }

  factory Contacto.fromMap(Map<String, dynamic> map) {
    return Contacto(
      idContacto: map['id_contacto'],
      userId:
          map['user_id'] ??
          map['id_usuario'], // Support both old and new field names for migration
      nombre: map['nombre'],
      email: map['email'],
      telefono: map['telefono'],
      banco: map['banco'],
      cuentaDestino: map['cuenta_destino'],
      notas: map['notas'],
      favorito: map['favorito'] == 1,
    );
  }
}
