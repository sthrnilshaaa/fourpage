/// Contributor domain entity with roles (author, editor, translator, illustrator, narrator).
library;

class Contributor {
  final String name;
  final String role; // aut, edt, trl, ill, nrt, etc.
  final String? fileAs;
  final String? identifier;

  const Contributor({
    required this.name,
    this.role = 'aut',
    this.fileAs,
    this.identifier,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'fileAs': fileAs,
        'identifier': identifier,
      };

  factory Contributor.fromJson(Map<String, dynamic> json) => Contributor(
        name: json['name'] as String,
        role: json['role'] as String? ?? 'aut',
        fileAs: json['fileAs'] as String?,
        identifier: json['identifier'] as String?,
      );
}
