{{- $iname := "Storage" -}}
// {{ $iname }} is interface structure for database operation that can be called
type {{ $iname }} interface {
{{- range .Tables }}
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
    {{- if .PrimaryKey }}
    // Insert inserts the {{ .Name }} to the database.
    Insert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    // Delete deletes the {{ .Name }} from the database.
    Delete{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    {{- if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
        // Update updates the {{ .Name }} in the database.
        Update{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Save saves the {{ .Name }} to the database.
        Save{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Upsert performs an upsert for {{ .Name }}.
        Upsert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    {{- else }}
        // Update statements omitted due to lack of fields other than primary key
    {{- end }}
    {{- end }}
{{- end }}

{{- range .Views }}
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}

    {{- if .PrimaryKey }}
    // Insert inserts the {{ .Name }} to the database.
    Insert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    // Delete deletes the {{ .Name }} from the database.
    Delete{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    {{- if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
        // Update updates the {{ .Name }} in the database.
        Update{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Save saves the {{ .Name }} to the database.
        Save{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Upsert performs an upsert for {{ .Name }}.
        Upsert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    {{- else }}
        // Update statements omitted due to lack of fields other than primary key
    {{- end }}

    {{- end }}
{{- end }}

{{- range .Foreign }}
    {{- $short := (shortname .Type.Name) }}
    // {{ .Name }}By{{ .Type.Name }}{{ .RefField.Name }} returns the {{ .RefType.Name }} associated with the {{ .Type.Name }}'s {{ .Field.Name }} ({{ .Field.Col.ColumnName }}).
    // Generated from foreign key '{{ .ForeignKey.ForeignKeyName }}'.
    {{ .Name }}By{{ .Type.Name }}{{ .RefField.Name }}(db XODB, {{ $short }} *{{ .Type.Name }}) (*{{ .RefType.Name }}, error)
{{- end }}

{{- range .Indexes }}

{{- end }}
}

{{ range .Drivers }}
    {{ $udriver := (firstletterupper .) }}
    // {{ $udriver }}{{ $iname }} is {{ $udriver }} for the database.
    type {{ $udriver }}{{ $iname }} struct {}
{{- end }}


// New is a construction method that return a new Storage
func New(driver string, c Config) (Storage, error) {
	var s Storage
	switch driver {
{{- range .Drivers }}
    {{- $driver := . -}}
    {{- $udriver := (firstletterupper $driver) }}
	case "{{ $driver }}":
		s = &{{ $udriver }}{{ $iname }}{}
{{- end }}
	default:
		return nil, errors.New("driver " + driver + " not support")
	}

	logger = c.Logger
	return s, nil
}

{{ range .Tables }}
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
    {{- $table := (schema .Schema .Table.TableName) -}}
    {{- if .Comment -}}
    // {{ .Comment }}
    {{- else -}}
    // {{ .Name }} represents a row from '{{ $table }}'.
    {{- end }}
    type {{ .Name }} struct {
    {{- range .Fields }}
        {{ .Name }} {{ retype .Type }} `json:"{{ .Col.ColumnName }}"` // {{ .Col.ColumnName }}
    {{- end }}
    {{- if .PrimaryKey }}

        // xo fields
        _exists, _deleted bool
    {{ end }}
    }

    {{ if .PrimaryKey }}
    // Exists determines if the {{ .Name }} exists in the database.
    func ({{ $short }} *{{ .Name }}) Exists() bool {
        return {{ $short }}._exists
    }

    // Deleted provides information if the {{ .Name }} has been deleted from the database.
    func ({{ $short }} *{{ .Name }}) Deleted() bool {
        return {{ $short }}._deleted
    }

    {{- end }}
{{- end }}


{{ range .Views }}
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
    {{- $table := (schema .Schema .Table.TableName) -}}
    {{- if .Comment -}}
    // {{ .Comment }}
    {{- else -}}
    // {{ .Name }} represents a row from '{{ $table }}'.
    {{- end }}
    type {{ .Name }} struct {
    {{- range .Fields }}
        {{ .Name }} {{ retype .Type }} `json:"{{ .Col.ColumnName }}"` // {{ .Col.ColumnName }}
    {{- end }}
    {{- if .PrimaryKey }}

        // xo fields
        _exists, _deleted bool
    {{ end }}
    }

    {{ if .PrimaryKey }}
    // Exists determines if the {{ .Name }} exists in the database.
    func ({{ $short }} *{{ .Name }}) Exists() bool {
        return {{ $short }}._exists
    }

    // Deleted provides information if the {{ .Name }} has been deleted from the database.
    func ({{ $short }} *{{ .Name }}) Deleted() bool {
        return {{ $short }}._deleted
    }

    {{- end }}
{{- end }}
