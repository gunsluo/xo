{{- $short := (shortname .Name "err" "res" "sqlstr" "db" "xoLog") -}}
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

{{ if .Table.ManualPk }}
	// sql insert query, primary key must be provided
	const sqlstr = `INSERT INTO {{ $table }} (` +
		`{{ colnames .Fields }}` +
		`) VALUES (` +
		`{{ colvals .Fields }}` +
		`)`

	// run query
	s.info(sqlstr, {{ fieldnames .Fields $short }})
	err = db.QueryRow(sqlstr, {{ fieldnames .Fields $short }}).Scan(&{{ $short }}.{{ .PrimaryKey.Name }})
	if err != nil {
		return err
	}
{{ else }}
	// sql insert query, primary key provided by sequence
	const sqlstr = `INSERT INTO {{ $table }} (` +
		`{{ colnames .Fields .PrimaryKey.Name }}` +
		`) VALUES (` +
		`{{ colvals .Fields .PrimaryKey.Name }}` +
		`) RETURNING {{ colname .PrimaryKey.Col }}`

	// run query
	s.info(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }})
	err = db.QueryRow(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }}).Scan(&{{ $short }}.{{ .PrimaryKey.Name }})
	if err != nil {
		return err
	}
{{ end }}

	// set existence
	{{ $short }}._exists = true

	return nil
}

// Insert{{ .Name }}ByFields inserts the {{ .Name }} to the database.
func (s *{{ $dname }}) Insert{{ .Name }}ByFields(db XODB, {{ $short }} *{{ .Name }}) error {
	var err error

    {{ $length := minus (len .Fields) 1 }}
    {{ $sn := shortname .Name }}
    params := make([]interface{}, 0, {{ $length }})
    fields := make([]string, 0, {{ $length }})
    retCols := `{{ (colname .PrimaryKey.Col) }}`
    retVars := make([]interface{}, 0, {{ $length }})
    retVars = append(retVars, &{{ $sn }}.{{ .PrimaryKey.Name }})
	
	{{- range $index, $field := .Fields -}}
	    {{ if (not (and $field.Col.IsPrimaryKey (not $.Table.ManualPk))) -}}
		    {{ if $field.Col.NotNull }}
                fields = append(fields, `{{ (colname $field.Col) }}`)
                params = append(params, {{ $sn }}.{{ $field.Name }})
		    {{ else -}}
                if {{ $sn }}.{{ $field.Name }}.Valid {
                    fields = append(fields, `{{ (colname $field.Col) }}`)
                    params = append(params, {{ $sn }}.{{ $field.Name }})
                } else {
                    retCols += `, {{ (colname $field.Col) }}`
                    retVars = append(retVars, &{{ $sn }}.{{ $field.Name }})
                }
            {{ end -}}
        {{ end -}}
    {{ end -}}

    if len(params) == 0 {
        // FIXME(jackie): maybe we should allow this?
        return errors.New("all fields are empty, unable to insert")
    }

    var placeHolders []string
    var placeHolderVals []interface{}
    for i := range params {
        placeHolders = append(placeHolders, "{{ mask }}")
        placeHolderVals = append(placeHolderVals, i+1)
    }
	placeHolderStr := fmt.Sprintf(strings.Join(placeHolders, ","), placeHolderVals...)

    sqlstr := `INSERT INTO {{ $table }} (` +
               strings.Join(fields, ",") +
               `) VALUES (` + placeHolderStr +
               `) RETURNING ` + retCols

    s.info(sqlstr, params)
    err = db.QueryRow(sqlstr, params...).Scan(retVars...)
    if err != nil {
        return err
    }

	// set existence
	{{ $short }}._exists = true

	return nil
}

{{ if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
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

		{{ if gt ( len .PrimaryKeyFields ) 1 }}
			// sql query with composite primary key
			{{ if gt (colcount .Fields .PrimaryKeyFields) 1 }}
				const sqlstr = `UPDATE {{ $table }} SET (` +
					`{{ colnamesmulti .Fields .PrimaryKeyFields }}` +
					`) = ( ` +
					`{{ colvalsmulti .Fields .PrimaryKeyFields }}` +
					`) WHERE {{ colnamesquerymulti .PrimaryKeyFields " AND " (getstartcount .Fields .PrimaryKeyFields) nil }}`
			{{- else }}
				const sqlstr = `UPDATE {{ $table }} SET ` +
					`{{ colnamesmulti .Fields .PrimaryKeyFields }}` +
					` = ` +
					`{{ colvalsmulti .Fields .PrimaryKeyFields }}` +
					` WHERE {{ colnamesquerymulti .PrimaryKeyFields " AND " (getstartcount .Fields .PrimaryKeyFields) nil }}`
			{{- end }}

			// run query
			s.info(sqlstr, {{ fieldnamesmulti .Fields $short .PrimaryKeyFields }}, {{ fieldnames .PrimaryKeyFields $short}})
			_, err = db.Exec(sqlstr, {{ fieldnamesmulti .Fields $short .PrimaryKeyFields }}, {{ fieldnames .PrimaryKeyFields $short}})
		return err
		{{- else }}
			// sql query
			{{ if gt (colcount .Fields .PrimaryKey.Name) 1 }}
				const sqlstr = `UPDATE {{ $table }} SET (` +
					`{{ colnames .Fields .PrimaryKey.Name }}` +
					`) = ( ` +
					`{{ colvals .Fields .PrimaryKey.Name }}` +
					`) WHERE {{ colname .PrimaryKey.Col }} = {{ collastvals .Fields .PrimaryKey.Name }}`
			{{- else }}
				const sqlstr = `UPDATE {{ $table }} SET ` +
					`{{ colnames .Fields .PrimaryKey.Name }}` +
					` = ` +
					`{{ colvals .Fields .PrimaryKey.Name }}` +
					` WHERE {{ colname .PrimaryKey.Col }} = {{ collastvals .Fields .PrimaryKey.Name }}`
			{{- end }}

			// run query
			s.info(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }}, {{ $short }}.{{ .PrimaryKey.Name }})
			_, err = db.Exec(sqlstr, {{ fieldnames .Fields $short .PrimaryKey.Name }}, {{ $short }}.{{ .PrimaryKey.Name }})
			return err
		{{- end }}
	}

	// Update{{ .Name }}ByFields updates the {{ .Name }} in the database.
	func (s *{{ $dname }}) Update{{ .Name }}ByFields(db XODB, {{ $short }} *{{ .Name }}, fields, retCols []string, params, retVars []interface{}) error {
        var placeHolders []string
        var idxvals []interface{}
        for i := range params {
            placeHolders = append(placeHolders, "{{ mask }}")
            idxvals = append(idxvals, i+1)
        }
        params = append(params, {{ $short }}.{{ .PrimaryKey.Name }})
	    idxvals = append(idxvals, len(params))

        var sqlstr string
        if len(fields) == 1 {
            sqlstr = fmt.Sprintf(`UPDATE {{ $table }} SET ` +
                strings.Join(fields, ",") +
                ` = ` + strings.Join(placeHolders, ",") +
                ` WHERE id = {{ mask }}` +
                ` RETURNING ` + strings.Join(retCols, ", "), idxvals...)
        } else {
            sqlstr = fmt.Sprintf(`UPDATE {{ $table }} SET (` +
                strings.Join(fields, ",") +
                `) = (` + strings.Join(placeHolders, ",") +
                `) WHERE {{ colname .PrimaryKey.Col }} = {{ mask }}` +
                ` RETURNING ` + strings.Join(retCols, ", "), idxvals...)
        }
		s.info(sqlstr, params)
        if err := db.QueryRow(sqlstr, params...).Scan(retVars...); err != nil {
            return err
        }

        return nil
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
		var err error

		// sql query
		const sqlstr = `INSERT INTO {{ $table }} (` +
			`{{ colnames .Fields }}` +
			`) VALUES (` +
			`{{ colvals .Fields }}` +
			`) ON CONFLICT ({{ colnames .PrimaryKeyFields }}) DO UPDATE SET (` +
			`{{ colnames .Fields }}` +
			`) = (` +
			`{{ colprefixnames .Fields "EXCLUDED" }}` +
			`)`

		// run query
		s.info(sqlstr, {{ fieldnames .Fields $short }})
		_, err = db.Exec(sqlstr, {{ fieldnames .Fields $short }})
		if err != nil {
			return err
		}

		// set existence
		{{ $short }}._exists = true

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

	{{ if gt ( len .PrimaryKeyFields ) 1 }}
		// sql query with composite primary key
		const sqlstr = `DELETE FROM {{ $table }}  WHERE {{ colnamesquery .PrimaryKeyFields " AND " }}`

		// run query
		s.info(sqlstr, {{ fieldnames .PrimaryKeyFields $short }})
		_, err = db.Exec(sqlstr, {{ fieldnames .PrimaryKeyFields $short }})
		if err != nil {
			return err
		}
	{{- else }}
		// sql query
		const sqlstr = `DELETE FROM {{ $table }} WHERE {{ colname .PrimaryKey.Col }} = {{ colnumval 1 }}`

		// run query
		s.info(sqlstr, {{ $short }}.{{ .PrimaryKey.Name }})
		_, err = db.Exec(sqlstr, {{ $short }}.{{ .PrimaryKey.Name }})
		if err != nil {
			return err
		}
	{{- end }}

	// set deleted
	{{ $short }}._deleted = true

	return nil
}

// Delete{{ .Name }}s deletes the {{ .Name }} from the database.
func (s *{{ $dname }}) Delete{{ .Name }}s(db XODB, {{ $short }}s []*{{ .Name }}) error {
	var err error

	if len({{ $short }}s) == 0 {
		return nil
	}

	
	{{ if gt ( len .PrimaryKeyFields ) 1 }}
	    {{- range .PrimaryKeyFields }}
            var args{{ .Name }} []interface{}
            var placeholder{{ .Name }} string
	    {{- end }}

        for i, {{ $short }} := range {{ $short }}s {
            {{- range .PrimaryKeyFields }}
                args{{ .Name }} = append(args{{ .Name }}, {{ $short }}.{{ .Name }})
                if i != 0 {
                    placeholder{{ .Name }} = placeholder{{ .Name }} + ", "
                }
                placeholder{{ .Name }} += fmt.Sprintf("{{ mask }}", i+1)
            {{- end }}
        }

	    var args []interface{}
        var where string
	    {{- range $i, $f := .PrimaryKeyFields }}
	        args = append(args, args{{ $f.Name }}...)
            {{ if eq $i 0 }}
                where += `{{ (colname $f.Col) }} in (` + placeholder{{ $f.Name }} + `)`
            {{- else }}
                where += ` AND {{ (colname $f.Col) }} in (` + placeholder{{ $f.Name }} + `)`
            {{- end }}
	    {{- end }}

		// sql query with composite primary key
		var sqlstr = `DELETE FROM {{ $table }} WHERE ` + where

		// run query
		s.info(sqlstr, args)
		_, err = db.Exec(sqlstr, args...)
		if err != nil {
			return err
		}
	{{- else }}
        var args []interface{}
        var placeholder string
        for i, {{ $short }} := range {{ $short }}s {
            args = append(args, {{ $short }}.{{ .PrimaryKey.Name }})
            if i != 0 {
                placeholder = placeholder + ", "
            }
            placeholder += fmt.Sprintf("{{ mask }}", i+1)
        }

        // sql query
        var sqlstr = `DELETE FROM {{ $table }} WHERE {{ colname .PrimaryKey.Col }} in (` + placeholder + `)`

        // run query
        s.info(sqlstr, args)
        _, err = db.Exec(sqlstr, args...)
        if err != nil {
            return err
        }
	{{- end }}

	// set deleted
	for _, {{ $short }} := range {{ $short }}s {
	    {{ $short }}._deleted = true
	}

	return nil
}
{{- end }}

// GetMostRecent{{ .Name }} returns n most recent rows from '{{ .Table.TableName }}',
// ordered by "created_date" in descending order.
func (s *{{ $dname }}) GetMostRecent{{ .Name }}(db XODB, n int) ([]*{{ .Name }}, error) {
	const sqlstr = `SELECT ` +
		`{{ colnames .Fields }} ` +
		`FROM {{ $table }} ` +
		`ORDER BY {{ parsecolname "created_date" }} DESC LIMIT {{ colnumval 1}}`

	s.info(sqlstr, n)
	q, err := db.Query(sqlstr, n)
	if err != nil {
		return nil, err
	}
	defer q.Close()

	// load results
	var res []*{{ .Name }}
	for q.Next() {
		{{ $short }} := {{ .Name }}{}

		// scan
		err = q.Scan({{ fieldnames .Fields (print "&" $short) }})
		if err != nil {
			return nil, err
		}

		res = append(res, &{{ $short }})
	}

	return res, nil
}

// GetMostRecentChanged{{ .Name }} returns n most recent rows from '{{ .Table.TableName }}',
// ordered by "changed_date" in descending order.
func (s *{{ $dname }}) GetMostRecentChanged{{ .Name }}(db XODB, n int) ([]*{{ .Name }}, error) {
	const sqlstr = `SELECT ` +
		`{{ colnames .Fields }} ` +
		`FROM {{ $table }} ` +
		`ORDER BY {{ parsecolname "changed_date" }} DESC LIMIT {{ colnumval 1}}`

	s.info(sqlstr, n)
	q, err := db.Query(sqlstr, n)
	if err != nil {
		return nil, err
	}
	defer q.Close()

	// load results
	var res []*{{ .Name }}
	for q.Next() {
		{{ $short }} := {{ .Name }}{}

		// scan
		err = q.Scan({{ fieldnames .Fields (print "&" $short) }})
		if err != nil {
			return nil, err
		}

		res = append(res, &{{ $short }})
	}

	return res, nil
}

// GetAll{{ .Name }} returns all rows from '{{ .Table.TableName }}', based on the {{ .Name }}QueryArguments.
// If the {{ .Name }}QueryArguments is nil, it will use the default {{ .Name }}QueryArguments instead.
func (s *{{ $dname }}) GetAll{{ .Name }}(db XODB, queryArgs *{{ .Name }}QueryArguments) ([]*{{ .Name }}, error) { // nolint: gocyclo
	queryArgs = Apply{{ .Name }}QueryArgsDefaults(queryArgs)
{{- if (existsqlfilter .) }}
	if queryArgs.filterArgs == nil{
		filterArgs, err := get{{ .Name }}Filter(queryArgs.Where)
		if err != nil {
			return nil, errors.Wrap(err, "unable to get {{ .Name }} filter")
		}
		queryArgs.filterArgs = filterArgs
	}
{{- end }}

	desc := ""
	if *queryArgs.Desc {
		desc = "DESC"
	}

	dead := "NULL"
	if *queryArgs.Dead {
		dead = "NOT NULL"
	}

	orderBy := "{{ $.PrimaryKey.Col.ColumnName }}"
	foundIndex := false
	dbFields := map[string]bool {
	{{- range .Fields }}
	"{{ .Col.ColumnName }}":true,
	{{- end }}
	}

	if *queryArgs.OrderBy != "" && *queryArgs.OrderBy != defaultOrderBy {
		foundIndex = dbFields[*queryArgs.OrderBy]
		if !foundIndex{
            return nil, fmt.Errorf("unable to order by %s, field not found",*queryArgs.OrderBy)
		}
		orderBy=*queryArgs.OrderBy
	}

	var params []interface{}
	placeHolders := ""
{{- if (existsqlfilter .) }}
	if queryArgs.filterArgs != nil{
		pls := make([]string, len(queryArgs.filterArgs.filterPairs))
		for i, pair := range queryArgs.filterArgs.filterPairs {
		   pls[i] = fmt.Sprintf("%s %s {{ mask }}", pair.fieldName, pair.option, i+1)
		   params = append(params, pair.value)
	   }
	   placeHolders = strings.Join(pls, " " + queryArgs.filterArgs.conjunction + " ")
	   placeHolders = fmt.Sprintf("(%s) AND", placeHolders)
	}
{{- end }}
	params = append(params, *queryArgs.Offset)
	offsetPos := len(params)

	params = append(params, *queryArgs.Limit)
	limitPos := len(params)
	
	var sqlstr = fmt.Sprintf(`SELECT %s FROM %s WHERE %s {{ parsecolname "deleted_date" }} IS %s ORDER BY {{ parsecolname "%s" }} %s OFFSET {{ mask }} LIMIT {{ mask }}`,
		`{{ colnames .Fields }} `,
		`{{ $table }}`,
		placeHolders,
		dead,
		orderBy,
		desc,
		offsetPos,
		limitPos)
	s.info(sqlstr, params)

	q, err := db.Query(sqlstr, params...)
	if err != nil {
		return nil, err
	}
	defer q.Close()

	// load results
	var res []*{{ .Name }}
	for q.Next() {
		{{ $short }} := {{ .Name }}{}

		// scan
		err = q.Scan({{ fieldnames .Fields (print "&" $short) }})
		if err != nil {
			return nil, err
		}

		res = append(res, &{{ $short }})
	}

	return res, nil
}

// CountAll{{ .Name }} returns a count of all rows from '{{ .Table.TableName }}'
func (s *{{ $dname }}) CountAll{{ .Name }}(db XODB, queryArgs *{{ .Name }}QueryArguments) (int, error) {
	queryArgs = Apply{{ .Name }}QueryArgsDefaults(queryArgs)
{{- if (existsqlfilter .) }}
	if queryArgs.filterArgs == nil{
		filterArgs, err := get{{ .Name }}Filter(queryArgs.Where)
		if err != nil {
			return 0, errors.Wrap(err, "unable to get {{ .Name }} filter")
		}
		queryArgs.filterArgs = filterArgs
	}
{{- end }}

	dead := "NULL"
	if *queryArgs.Dead {
		dead = "NOT NULL"
	}

	var params []interface{}
	placeHolders := ""
{{- if (existsqlfilter .) }}
	if queryArgs.filterArgs != nil{
		pls := make([]string, len(queryArgs.filterArgs.filterPairs))
		for i, pair := range queryArgs.filterArgs.filterPairs {
		   pls[i] = fmt.Sprintf("%s %s {{ mask }}", pair.fieldName, pair.option, i+1)
		   params = append(params, pair.value)
	   }
	   placeHolders = strings.Join(pls, " " + queryArgs.filterArgs.conjunction + " ")
	   placeHolders = fmt.Sprintf("(%s) AND", placeHolders)
	}
{{- end }}

	var err error
	var sqlstr = fmt.Sprintf(`SELECT count(*) from {{ $table }} WHERE %s {{ parsecolname "deleted_date" }} IS %s`, placeHolders, dead)
	s.info(sqlstr)

	var count int
	err = db.QueryRow(sqlstr, params...).Scan(&count)
	if err != nil {
		return -1, err
	}
	return count, nil
}

{{ range .ForeignKeys }}
	{{- $fnname := (print (plural $.Name) "By" .Field.Name "FK") -}}
	{{- if not (isdup $fnname "postgres") }}
	// {{ $fnname }} retrieves rows from {{ $table }} by foreign key {{.Field.Name}}.
	// Generated from foreign key {{.Name}}.
	func (s *{{ $dname }}) {{ $fnname }}(db XODB, {{ togqlname .Field.Name }} {{ .RefField.Type }}, queryArgs *{{ $.Name }}QueryArguments) ([]*{{$.Name}}, error) {
		queryArgs = Apply{{ $.Name }}QueryArgsDefaults(queryArgs)

		desc := ""
		if *queryArgs.Desc {
			desc = "DESC"
		}

		dead := "NULL"
		if *queryArgs.Dead {
			dead = "NOT NULL"
		}

		var params []interface{}
		placeHolders := ""
{{- if (existsqlfilter .Type) }}
		if queryArgs.filterArgs != nil{
			pos := 0
			pls := make([]string, 0, len(queryArgs.filterArgs.filterPairs))
			for _, pair := range queryArgs.filterArgs.filterPairs {
				if pair.fieldName == "{{ .Field.Col.ColumnName }}"{
					return nil, fmt.Errorf("already have condition on field:{{ .Field.Name }}, because of foregin key {{ .Name }}")
				}
				pos++
				pls = append(pls, fmt.Sprintf("%s %s {{ mask }}", pair.fieldName, pair.option, pos))
				params = append(params, pair.value)
			}
			placeHolders = strings.Join(pls, " " + queryArgs.filterArgs.conjunction + " ")
			placeHolders = fmt.Sprintf("(%s) AND", placeHolders)
		}
{{- end }}
		params = append(params, {{ togqlname .Field.Name }})
		placeHolders = fmt.Sprintf(`%s {{ colname .Field.Col }} = {{ mask }} AND `, placeHolders, len(params))

		params = append(params, *queryArgs.Offset)
		offsetPos := len(params)

		params = append(params, *queryArgs.Limit)
		limitPos := len(params)

		var sqlstr = fmt.Sprintf(
			`SELECT %s FROM %s WHERE %s {{ parsecolname "deleted_date" }} IS %s ORDER BY {{ parsecolname "%s" }} %s OFFSET {{ mask }} LIMIT {{ mask }}`,
			`{{ colnames $.Fields }} `,
			`{{ $table }}`,
			placeHolders,
			dead,
			"{{ $.PrimaryKey.Col.ColumnName }}",
			desc,
			offsetPos,
			limitPos)

	    s.info(sqlstr, params...)
		q, err := db.Query(sqlstr, params...)
		if err != nil {
			return nil, err
		}
		defer q.Close()

		// load results
		var res []*{{ $.Name }}
		for q.Next() {
			{{ $short }} := {{ $.Name }}{}

			// scan
			err = q.Scan({{ fieldnames $.Fields (print "&" $short) }})
			if err != nil {
				return nil, err
			}

			res = append(res, &{{ $short }})
		}

		return res, nil
	}

	// Count{{ $fnname }} count rows from {{ $table }} by foreign key {{.Field.Name}}.
	// Generated from foreign key {{.Name}}.
	func (s *{{ $dname }}) Count{{ $fnname }}(db XODB, {{ togqlname .Field.Name }} {{ .RefField.Type }}, queryArgs *{{ $.Name }}QueryArguments) (int, error) {
		queryArgs = Apply{{ $.Name }}QueryArgsDefaults(queryArgs)

		dead := "NULL"
		if *queryArgs.Dead {
			dead = "NOT NULL"
		}

		var params []interface{}
		placeHolders := ""
{{- if (existsqlfilter .Type) }}
		if queryArgs.filterArgs != nil{
			pos := 0
			pls := make([]string, 0, len(queryArgs.filterArgs.filterPairs))
			for _, pair := range queryArgs.filterArgs.filterPairs {
				if pair.fieldName == "{{ .Field.Col.ColumnName }}"{
					return -1, fmt.Errorf("already have condition on field:{{ .Field.Name }}, because of foregin key {{ .Name }}")
				}
				pos++
				pls = append(pls, fmt.Sprintf("%s %s {{ mask }}", pair.fieldName, pair.option, pos))
				params = append(params, pair.value)
			}
			placeHolders = strings.Join(pls, " " + queryArgs.filterArgs.conjunction + " ")
			placeHolders = fmt.Sprintf("(%s) AND", placeHolders)
		}
{{- end }}
		params = append(params, {{ togqlname .Field.Name }})
		placeHolders = fmt.Sprintf(`%s {{ colname .Field.Col }} = {{ mask }} AND `, placeHolders, len(params))

		var err error
		var sqlstr = fmt.Sprintf(`SELECT count(*) from {{ $table }} WHERE %s {{ parsecolname "deleted_date" }} IS %s`, placeHolders, dead)
		s.info(sqlstr)

		var count int
		err = db.QueryRow(sqlstr, params...).Scan(&count)
		if err != nil {
			return -1, err
		}
		return count, nil
	}
	{{end}}
{{ end}}

