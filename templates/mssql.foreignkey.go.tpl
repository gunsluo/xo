{{- $short := (shortname .Type.Name) -}}
{{- $dname := (print (firstletterupper (driver) ) "Storage") -}}
// {{ .Name }}In{{ .Type.Name }} returns the {{ .RefType.Name }} associated with the {{ .Type.Name }}'s {{ .Field.Name }} ({{ .Field.Col.ColumnName }}).
//
// Generated from foreign key '{{ .ForeignKey.ForeignKeyName }}'.
func (s *{{ $dname }}) {{ .Name }}In{{ .Type.Name }}(db XODB, {{ $short }} *{{ .Type.Name }}) (*{{ .RefType.Name }}, error) {
	return s.{{ .RefType.Name }}By{{ .RefField.Name }}(db, {{ convext $short .Field .RefField }})
}
