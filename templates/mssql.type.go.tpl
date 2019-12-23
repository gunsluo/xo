{{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $table := (schema .Schema .Table.TableName) -}}
{{- $dname := (print (firstletterupper (driver) ) "Storage") -}}

{{ if .PrimaryKey }}
// Insert{{ .Name }} inserts the {{ .Name }} to the database.
func (s *{{ $dname }}) Insert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error {
	var err error

	// if already exist, bail
	if {{ $short }}._exists {
		return errors.New("insert failed: already exists")
	}

{{ if .Table.ManualPk  }}
	// sql insert query, primary key must be provided
	const sqlstr = `INSERT INTO {{ $table }} (` +
		`{{ colnames .Fields }}` +
		`) VALUES (` +
		`{{ colvals .Fields }}` +
		`)`

	// run query
	XOLog(sqlstr, {{ fieldnames .Fields $short }})
	_, err = db.Exec(sqlstr, {{ fieldnames .Fields $short }})
	if err != nil {
		return err
	}

	// set existence
	{{ $short }}._exists = true
{{ else }}
	// sql insert query, primary key provided by identity
	const sqlstr = `INSERT INTO {{ $table }} (` +
		`{{ colnames .Fields .PrimaryKey.Name }}` +
		`) VALUES (` +
		`{{ colvals .Fields .PrimaryKey.Name }}` +
		`)`

	// run query
	XOLog(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }})
	res, err := db.Exec(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }})
	if err != nil {
		return err
	}

	// retrieve id
	id, err := res.LastInsertId()
	if err != nil {
		return err
	}

	// set primary key and existence
	{{ $short }}.{{ .PrimaryKey.Name }} = {{ .PrimaryKey.Type }}(id)
	{{ $short }}._exists = true
{{ end }}

	return nil
}

{{ if ne (fieldnames .Fields $short .PrimaryKey.Name) "" }}
	// Update{{ .Name }} updates the {{ .Name }} in the database.
	func (s *{{ $dname }}) Update{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error {
		var err error

		// if doesn't exist, bail
		if !{{ $short }}._exists {
			return errors.New("update failed: does not exist")
		}

		// if deleted, bail
		if {{ $short }}._deleted {
			return errors.New("update failed: marked for deletion")
		}

		// sql query
		const sqlstr = `UPDATE {{ $table }} SET ` +
			`{{ colnamesquery .Fields ", " .PrimaryKey.Name }}` +
			` WHERE {{ colname .PrimaryKey.Col }} = ${{ colcount .Fields .PrimaryKey.Name }}`

		// run query
		XOLog(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }}, {{ $short }}.{{ .PrimaryKey.Name }})
		_, err = db.Exec(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }}, {{ $short }}.{{ .PrimaryKey.Name }})
		return err
	}

	// Save{{ .Name }} saves the {{ .Name }} to the database.
	func (s *{{ $dname }}) Save{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error {
		if {{ $short }}.Exists() {
			return s.Update{{ .Name }}(db, {{ $short }})
		}

		return s.Insert{{ .Name }}(db, {{ $short }})
	}

	// Upsert{{ .Name }} performs an upsert for {{ .Name }}.
	func (s *{{ $dname }}) Upsert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error {
		return nil
	}
{{ else }}
	// Update statements omitted due to lack of fields other than primary key
{{ end }}

// Delete{{ .Name }} deletes the {{ .Name }} from the database.
func (s *{{ $dname }}) Delete{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error {
	var err error

	// if doesn't exist, bail
	if !{{ $short }}._exists {
		return nil
	}

	// if deleted, bail
	if {{ $short }}._deleted {
		return nil
	}

	// sql query
	const sqlstr = `DELETE FROM {{ $table }} WHERE {{ colname .PrimaryKey.Col }} = $1`

	// run query
	XOLog(sqlstr, {{ $short }}.{{ .PrimaryKey.Name }})
	_, err = db.Exec(sqlstr, {{ $short }}.{{ .PrimaryKey.Name }})
	if err != nil {
		return err
	}

	// set deleted
	{{ $short }}._deleted = true

	return nil
}
{{- end }}

