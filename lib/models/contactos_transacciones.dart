class ContactosTransacciones {
  final int idTransaccion;
  final int idContacto;

  ContactosTransacciones({
    required this.idTransaccion,
    required this.idContacto,
  });

  Map<String, dynamic> toMap() {
    return {'id_transaccion': idTransaccion, 'id_contacto': idContacto};
  }

  factory ContactosTransacciones.fromMap(Map<String, dynamic> map) {
    return ContactosTransacciones(
      idTransaccion: map['id_transaccion'],
      idContacto: map['id_contacto'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactosTransacciones &&
        other.idTransaccion == idTransaccion &&
        other.idContacto == idContacto;
  }

  @override
  int get hashCode => idTransaccion.hashCode ^ idContacto.hashCode;
}
