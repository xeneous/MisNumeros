class Contacto {
  final int idContacto;
  final int idUsuario;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? banco;
  final String? cuentaDestino;
  final String? notas;
  final bool favorito;

  Contacto({
    required this.idContacto,
    required this.idUsuario,
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
    int? idUsuario,
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
      idUsuario: idUsuario ?? this.idUsuario,
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
      'id_usuario': idUsuario,
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
      idUsuario: map['id_usuario'],
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
