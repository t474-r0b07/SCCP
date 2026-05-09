class AllowedAdmin {
  final String id;
  final String email;
  final String nombre;
  final String nivelAcceso; // SUDO, SUPERVISOR, SUPERVISOR_DTEX.
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? ultimoLogin;

  AllowedAdmin({
    required this.id,
    required this.email,
    required this.nombre,
    required this.nivelAcceso,
    this.activo = true,
    this.createdAt,
    this.updatedAt,
    this.ultimoLogin,
  });

  factory AllowedAdmin.fromJson(Map<String, dynamic> json) {
    return AllowedAdmin(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      nivelAcceso: json['nivel_acceso']?.toString() ?? 'SUPERVISOR',
      activo: json['activo'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      ultimoLogin: json['ultimo_login'] != null
          ? DateTime.parse(json['ultimo_login'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'nombre': nombre,
      'nivel_acceso': nivelAcceso,
      'activo': activo,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'ultimo_login': ultimoLogin?.toIso8601String(),
    };
  }

  String get nivelNormalizado => nivelAcceso.trim().toUpperCase();

  // Getters para nivel de acceso. Conservan DIRECTOR/ADMINISTRADOR para no
  // bloquear cuentas existentes mientras Supabase migra a los roles reales.
  bool get esDirector {
    return {
      'SUDO',
      'DIRECTOR',
      'ADMIN',
      'ADMINISTRADOR',
      'COMANDANTE',
    }.contains(nivelNormalizado);
  }

  bool get esSupervisor {
    return nivelNormalizado == 'SUPERVISOR' || esDirector;
  }

  bool get esSupervisorDtex => nivelNormalizado == 'SUPERVISOR_DTEX';

  bool get tieneAccesoDtex => esDirector || esSupervisor || esSupervisorDtex;

  String get nivelDisplay {
    switch (nivelNormalizado) {
      case 'SUDO':
        return 'SUPERUSUARIO';
      case 'SUPERVISOR_DTEX':
        return 'SUPERVISOR DTEX';
      case 'DIRECTOR':
      case 'ADMIN':
      case 'ADMINISTRADOR':
      case 'COMANDANTE':
        return 'COMANDANTE';
      case 'SUPERVISOR':
        return 'SUPERVISOR';
      default:
        return nivelAcceso;
    }
  }

  // Nivel numérico para compatibilidad
  int get nivelNumerico {
    switch (nivelNormalizado) {
      case 'SUDO':
      case 'DIRECTOR':
      case 'ADMIN':
      case 'ADMINISTRADOR':
      case 'COMANDANTE':
        return 3;
      case 'SUPERVISOR':
      case 'SUPERVISOR_DTEX':
        return 2;
      default:
        return 1;
    }
  }
}
