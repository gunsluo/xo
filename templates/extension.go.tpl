{{- $table := (schema .Schema .Table.TableName) -}}
{{- $idxFields := (flatidxfields .) -}}
{{ if (existsqlfilter .) }}
	// {{ .Name }}Filter related to {{ .Name }}QueryArguments
	// struct field name contain table column name in Camel style and logic operator(lt, gt etc)
	// only indexed column and special column defined in ExtraFilters declared in file extra_rules.yaml
	type {{ .Name }}Filter struct {
		Conjunction	*string  // enum in "AND", "OR", nil(consider as single condition)
	{{- range .Fields -}}
		{{- $ftyp := (sqlfilter $table . $idxFields) -}}
		{{- if (and (ne .Name $.PrimaryKey.Name) (ne $ftyp "unsupported")) -}}
			{{- if (or (eq $ftyp "Number") (eq $ftyp "String")) }}
				{{ .Name }} {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}"` // equal to {{ .Name }}
			{{- end -}}
			{{- if (eq $ftyp "String") }}
				{{ .Name }}Like {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_like"` // LIKE
				{{ .Name }}ILike {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_ilike"` // ILIKE case-insensitive
				{{ .Name }}NLike {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_nlike"` // NOT LIKE
				{{ .Name }}NILike {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_nilike"` // NOT ILIKE case-insensitive
			{{- end -}}
			{{- if (or (eq $ftyp "Number") (eq $ftyp "Time")) }}
				{{ .Name }}Lt {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_lt"` // less than {{ .Name }}
				{{ .Name }}Lte {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_lte"` // less than and equal to {{ .Name }}
				{{ .Name }}Gt {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_gt"` // greater than {{ .Name }}
				{{ .Name }}Gte {{ sqltogopointertype .Type .Col.IsPrimaryKey }} `json:"{{ togqlname .Name }}_gte"` // greater than and equal to {{ .Name }}
			{{- end -}}
		{{- end -}}
	{{- end }}
	}

	// {{ .Name }}QueryArguments composed by Cursor, {{ .Name }}Filter and sql filter string
	type {{ .Name }}QueryArguments struct{
		Cursor
		Where *{{ .Name }}Filter

		// non-export field
		filterArgs *filterArguments
	}

	// get{{ .Name }}Filter return the sql filter
	func get{{ .Name }}Filter(filter *{{ .Name }}Filter) (*filterArguments, error){
		if filter == nil{
			return nil, nil
		}
		conjunction := ""
		conjCnt := 0
		var filterPairs []*filterPair
		if filter.Conjunction != nil{
			conjunction = *filter.Conjunction
			if _, ok := sqlConjunctionMap[conjunction]; !ok{
				return nil, fmt.Errorf("unsupported conjunction:%v", filter.Conjunction)
			}
		}
	{{- range .Fields -}}
		{{- $ftyp := (sqlfilter $table . $idxFields) -}}
		{{- if (and (ne .Name $.PrimaryKey.Name) (ne $ftyp "unsupported")) -}}
			{{- if (or (eq $ftyp "Number") (eq $ftyp "String")) }}
				if filter.{{ .Name }} != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "=", value: *filter.{{ .Name }}})
				}
			{{- end -}}
			{{- if (eq $ftyp "String") }}
				if filter.{{ .Name }}Like != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "LIKE", value: *filter.{{ .Name }}Like})
				}
				if filter.{{ .Name }}ILike != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "ILIKE", value: *filter.{{ .Name }}ILike})
				}
				if filter.{{ .Name }}NLike != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "NOT LIKE", value: *filter.{{ .Name }}NLike})
				}
				if filter.{{ .Name }}NILike != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "NOT ILIKE", value: *filter.{{ .Name }}NILike})
				}
			{{- end -}}
			{{- if (eq $ftyp "Number") }}
				if filter.{{ .Name}}Lt != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "<", value: *filter.{{ .Name }}Lt})
				}else if filter.{{ .Name}}Lte != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "<=", value: *filter.{{ .Name }}Lte})
				}
				if filter.{{ .Name}}Gt != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: ">", value: *filter.{{ .Name }}Gt})
				}else if filter.{{ .Name}}Gte != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: ">=", value: *filter.{{ .Name }}Gte})
				}
			{{- end -}}
			{{- if (eq $ftyp "Time") }}
				if filter.{{ .Name}}Lt != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "<", value: filter.{{ .Name }}Lt.Time})
				}else if filter.{{ .Name}}Lte != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: "<=", value: filter.{{ .Name }}Lte.Time})
				}
				if filter.{{ .Name}}Gt != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: ">", value: filter.{{ .Name }}Gt.Time})
				}else if filter.{{ .Name}}Gte != nil{
					conjCnt++
					filterPairs = append(filterPairs, &filterPair{fieldName: "{{ .Col.ColumnName }}", option: ">=", value: filter.{{ .Name }}Gte.Time})
				}
			{{- end -}}
		{{- end -}}
	{{- end }}
		if conjCnt == 0{
			return nil, nil
		}
		if len(conjunction)>0 && conjCnt < 2{
			return nil, fmt.Errorf("invalid filter conjunction: %v need more than 2 parameter but have: %v", *filter.Conjunction, conjCnt)
		}
		if len(conjunction) == 0 && conjCnt != 1{
			return nil, fmt.Errorf("multi field:%v should be connected by conjunction AND or OR", conjCnt)
		}
		filterArgs := &filterArguments{filterPairs: filterPairs, conjunction: conjunction, conjCnt: conjCnt}
		return filterArgs, nil
	}

{{ else }}
	// {{ .Name }}QueryArguments composed by Cursor, {{ .Name }}Filter and sql filter string
	type {{ .Name }}QueryArguments struct {
		Cursor
	}
{{ end }}

// Apply{{ .Name }}QueryArgsDefaults assigns default cursor values to non-nil fields.
func Apply{{ .Name }}QueryArgsDefaults(queryArgs *{{ .Name }}QueryArguments) *{{ .Name }}QueryArguments {
	if queryArgs == nil {
		queryArgs = &{{ .Name }}QueryArguments{
			Cursor:DefaultCursor,
		}
		return queryArgs
	}
	if queryArgs.Offset == nil {
		queryArgs.Offset = DefaultCursor.Offset
	}
	if queryArgs.Limit == nil {
		queryArgs.Limit = DefaultCursor.Limit
	}
	if queryArgs.OrderBy == nil {
		queryArgs.OrderBy = DefaultCursor.OrderBy
	}
	if queryArgs.Desc == nil {
		queryArgs.Desc = DefaultCursor.Desc
	}
	if queryArgs.Dead == nil {
		queryArgs.Dead = DefaultCursor.Dead
	}
	if queryArgs.After == nil {
		queryArgs.After = DefaultCursor.After
	}
	if queryArgs.First == nil {
		queryArgs.First = DefaultCursor.First
	}
	if queryArgs.Before == nil {
		queryArgs.Before = DefaultCursor.Before
	}
	if queryArgs.Last == nil {
		queryArgs.Last = DefaultCursor.Last
	}
	return queryArgs
}

// extension block
{{- if (enableextension) }}
    const graphQL{{ .Name }}Queries = `
    {{- if (existsqlfilter .) }}
        all{{ plural .Name }}(where: {{ .Name }}Filter, offset: Int, limit: Int, orderBy: String, desc: Boolean): {{ .Name }}Connection!
    {{- else }}
        all{{ plural .Name }}(offset: Int, limit: Int, orderBy: String, desc: Boolean): {{ .Name }}Connection!
    {{- end -}}
    {{- range $x, $index := .Indexes }}
        {{ togqlname .FuncName }}(
        {{- range $i, $field := .Fields }}
          {{- togqlname .Name -}}:
          {{- sqltogqltype .Type .Col.IsPrimaryKey -}}
          {{- if not (islast $i (len $index.Fields)) -}}
          ,
          {{- end -}}
        {{- end -}}
        ):
        {{- if not .Index.IsUnique }}[{{ end }}{{- $.Name }}{{ if not .Index.IsUnique }}!]{{ end }}
    {{- end }}
    `

    const graphQL{{ .Name }}Mutations = `
        insert{{ plural .Name  }}(input: [Insert{{ .Name }}Input!]!): [{{ .Name }}!]!
        update{{ plural .Name  }}(input: [Update{{ .Name }}Input!]!): [{{ .Name }}!]!
        delete{{ plural .Name  }}(input: [Delete{{ .Name }}Input!]!): [ID!]!
    `

    var graphQL{{ .Name }}Types = `
        type {{ .Name }} {
    {{- range .Fields }}
        {{- $field := . -}}
        {{- with (getforeignkey .Name $.ForeignKeys) }}
            {{ togqlname (fkname $field.Name) }}: {{ .RefType.Name }}
        {{- else }}
            {{ togqlname .Name }}: {{ sqltogqltype .Type .Col.IsPrimaryKey }}
        {{- end }}
    {{- end }}

    {{- range .RefFKs -}}
    {{- if (existsqlfilter .Type) }}
            {{ togqlname .FkReverseField }}(where: {{ .Type.Name }}Filter, offset: Int, limit: Int, orderBy: String, desc: Boolean): {{ .Type.Name }}Connection!
    {{- else }}
            {{ togqlname .FkReverseField }}(offset: Int, limit: Int, orderBy: String, desc: Boolean): {{ .Type.Name }}Connection!
    {{- end -}}
    {{- end -}}
    {{- ""}}
        }

        type {{ .Name }}Connection {
            pageInfo: PageInfo!
            edges: [{{ .Name }}Edge]
            totalCount: Int
            {{ plural (togqlname .Name) }}: [{{ .Name }}]
        }

        type {{ .Name }}Edge {
            node: {{ .Name }}
            cursor: ID!
        }
    {{ if (existsqlfilter .) }}
        input {{ .Name }}Filter {
            conjunction: FilterConjunction
    {{- range .Fields -}}
        {{- $ftyp := (sqlfilter $table . $idxFields) -}}
        {{- if (and (ne .Name $.PrimaryKey.Name) (ne $ftyp "unsupported")) -}}
            {{- if (or (eq $ftyp "Number") (eq $ftyp "String")) }}
            {{ togqlname .Name  }}: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }}
            {{- end -}}
            {{- if (eq $ftyp "String") }}
            {{ togqlname .Name }}_like: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }} // LIKE
            {{ togqlname .Name }}_ilike: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }} // LIKE case insensitive
            {{ togqlname .Name }}_nlike: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }}	// NOT LIKE
            {{ togqlname .Name }}_nilike: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }} // NOT LIKE case insensitive
            {{- end -}}
            {{- if (or (eq $ftyp "Number") (eq $ftyp "Time")) }}
            {{ togqlname .Name  }}_lt: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }}
            {{ togqlname .Name  }}_lte: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }}
            {{ togqlname .Name  }}_gt: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }}
            {{ togqlname .Name  }}_gte: {{ sqltogqloptionaltype .Type .Col.IsPrimaryKey }}
            {{- end -}}
        {{- end -}}
    {{- end }}
        }
    {{- end }}

        input Insert{{ .Name }}Input {
    {{- range .Fields -}}
        {{- if ( or ($.Table.ManualPk) (ne .Name $.PrimaryKey.Name) ) }}
            {{ togqlname .Name }}: {{ sqltogqltype .Type .Col.IsPrimaryKey }}
        {{- end -}}
    {{- end }}
        }

        input Update{{ .Name }}Input {
    {{- range .Fields }}
            {{ togqlname .Name }}: {{ sqltogqltype (sqlniltype .Type) .Col.IsPrimaryKey }}
    {{- end }}
            _deletions: [String!]
        }

        input Delete{{ .Name }}Input {
    {{- range .Fields -}}
        {{- if eq .Name $.PrimaryKey.Name }}
            {{ togqlname .Name }}: {{ sqltogqltype .Type .Col.IsPrimaryKey }}
        {{- end -}}
    {{- end }}
        }
    `

    // Get{{ .Name }}Queries specifies the GraphQL queries for {{ .Name }}
    func (r *RootResolver) Get{{ .Name }}Queries() string {
        return graphQL{{ .Name }}Queries
    }

    // Get{{ .Name }}Mutations specifies the GraphQL mutations for {{ .Name }}
    func (r *RootResolver) Get{{ .Name }}Mutations() string {
        return graphQL{{ .Name }}Mutations
    }

    // Get{{ .Name }}Types specifies the GraphQL types for {{ .Name }}
    func (r *RootResolver) Get{{ .Name }}Types() string {
        return graphQL{{ .Name }}Types
    }

    // {{ .Name }}Resolver defines the GraphQL resolver for '{{ .Name }}'.
    type {{ .Name }}Resolver struct { 
        ext resolverExtensions
        node *{{ .Name }} 
    }

    // {{ .Name }}Resolver defines a GraphQL resolver for {{ .Name }}
    func New{{ .Name }}Resolver(node *{{ .Name }}, ext resolverExtensions) *{{ .Name }}Resolver {
        return &{{ .Name }}Resolver{ ext: ext, node: node }
    }

    // Node get node for {{ .Name }}Resolver
    func (r {{ .Name}}Resolver) Node() *{{ .Name }} {
        return r.node
    }

    {{- range .Fields -}}
        {{- $field := . -}}
        {{- with (getforeignkey .Name $.ForeignKeys) }}
            func (r {{ $.Name }}Resolver) {{ fkname $field.Name }}(ctx context.Context) (*{{ .RefType.Name }}Resolver, error) {

            {{- if (enableac) }}
                if r.ext.verifier == nil {
                    return nil, errors.New("enable ac, please set verifier")
                }
                if err := r.ext.verifier.VerifyRefAC(ctx, "{{ plural $.Name }}", "RefGet", r); err != nil {
                    return nil, errors.Wrap(err, "{{ plural $.Name }}:RefGet")
                }
            {{- end }}

                {{- $ot := .RefField.Type -}}
                {{- $it := $field.Type -}}
                {{- $varname := ( togqlname $field.Name ) -}}
                {{- if (eq $it $ot) }}
                    {{ $varname }} := r.node.{{$field.Name}}
                {{- else if (eq $it "int64") }}
                    {{ $varname }} := ({{ $ot }})(r.node.{{$field.Name}})
                {{- else if (eq $it "sql.NullInt64") }}
                    if !r.node.{{$field.Name}}.Valid {
                        return nil, nil  // here we should not throw error, because a foreign key might be allow null
                    }
                    {{ $varname }} := ({{ $ot }})(r.node.{{$field.Name}}.Int64)
                {{- else if (eq $it "sql.NullString") }}
                    if !r.node.{{$field.Name}}.Valid {
                        return nil, nil  // here we should not throw error, because a foreign key might be allow null
                    }
                    {{ $varname }} := r.node.{{$field.Name}}.String
                {{- else }}
                    panic("TODO: implement in extension.go.tpl {{ printf "input: %s, output %s" $it $ot }}")
                {{- end }}
                node, err := r.ext.storage.{{ .RefType.Name }}By{{ .RefField.Name }}(r.ext.db, {{$varname}})
                if err != nil {
                    return nil, errors.Wrap(err, "unable to retrieve {{ fkname $field.Name }}")
                }
                return New{{ .RefType.Name }}Resolver(node, r.ext), nil
            }
        {{- else }}
            {{- if (and (isacfield $table $field) (enableac)) }}
                 func (r {{ $.Name }}Resolver) {{ .Name }}(ctx context.Context) {{ sqltogotype .Type .Col.IsPrimaryKey }} {
                 if r.ext.verifier == nil {
                    return nil, errors.New("enable ac, please set verifier")
                 }
                 if err := r.ext.verifier.VerifyAC(ctx, "{{ plural $.Name }}.{{ .Name }}", "Get", r); err != nil {
                     return {{ sqltogoreturntype .Type .Col.IsPrimaryKey }}
                 }
                     return {{ sqltogql .Type (print "r.node." .Name) .Col.IsPrimaryKey }}
             }
            {{- else }}
                 func (r {{ $.Name }}Resolver) {{ .Name }}() {{ sqltogotype .Type .Col.IsPrimaryKey }} { return {{ sqltogql .Type (print "r.node." .Name) .Col.IsPrimaryKey }} }
            {{- end }}
        {{- end }}
    {{- end }}


    {{- range .RefFKs }}
    func (r {{ $.Name }}Resolver) {{ .FkReverseField }}(ctx context.Context, queryArgs *{{ .Type.Name }}QueryArguments) (*{{ .Type.Name }}ConnectionResolver, error){
        {{- if (enableac) }}
            if r.ext.verifier == nil {
                return nil, errors.New("enable ac, please set verifier")
            }
            if err := r.ext.verifier.VerifyRefAC(ctx, "{{ plural $.Name }}", "RefGet", r); err != nil {
                return nil, errors.Wrap(err, "{{ plural $.Name }}:RefGet")
            }
        {{- end }}

        if queryArgs != nil && (queryArgs.After != nil || queryArgs.First != nil || queryArgs.Before != nil || queryArgs.Last != nil) {
            return nil, errors.New("not implemented yet, use offset + limit for pagination")
        }

        queryArgs = Apply{{ .Type.Name }}QueryArgsDefaults(queryArgs)
    {{ if (existsqlfilter .Type) }}
        filterArgs, err := get{{ .Type.Name }}Filter(queryArgs.Where)
        if err != nil {
            return nil, errors.Wrap(err, "unable to get {{ .Type.Name }} filter")
        }
        queryArgs.filterArgs = filterArgs
    {{ end }}
        {{ $varname := (togqlname .RefField.Name) -}}
        {{ $varname }} := r.node.{{.RefField.Name}}

        data, err := r.ext.storage.{{ plural .Type.Name }}By{{.Field.Name}}FK(r.ext.db, {{ $varname }}, queryArgs)
        if err != nil {
            return nil, errors.Wrap(err, "unable to get {{plural .Type.Name}}")
        }

        count, err := r.ext.storage.Count{{ plural .Type.Name }}By{{.Field.Name}}FK(r.ext.db, {{ $varname }}, queryArgs)
        if err != nil {
            return nil, errors.Wrap(err, "unable to get {{plural .Type.Name}} count")
        }

        return &{{.Type.Name}}ConnectionResolver{
            ext: r.ext,
            data: data,
            count: int32(count),
        }, nil
    }
    {{- end }}

    {{- range $x := .Indexes }}
    // {{ .FuncName }} generated by {{ .Index.IndexName }}
    func (r *RootResolver) {{ .FuncName }}(ctx context.Context, args struct{
        {{- range $i, $field := .Fields }}
          {{ .Name }} {{ sqltogotype .Type .Col.IsPrimaryKey }}
        {{ end -}}
        }) ({{ if not .Index.IsUnique }}*[]{{ else }}*{{ end }}{{ .Type.Name }}Resolver, error) {
        {{- if (enableac) }}
            if r.ext.verifier == nil {
                return nil, errors.New("enable ac, please set verifier")
            }
            {{- if (isprimaryindex .) }}
            if err := r.ext.verifier.VerifyAC(ctx, "{{ plural $.Name }}", "Get", args); err != nil {
                return nil, errors.Wrap(err, "{{ plural $.Name }}:Get")
            }
            {{- else }}
            if err := r.ext.verifier.VerifyAC(ctx, "{{ plural $.Name }}.{{ .FuncName }}", "NonPrimaryKeyGet", args); err != nil {
                return nil, errors.Wrap(err, "{{ plural $.Name }}.{{ .FuncName }}:NonPrimaryKeyGet")
            }
            {{- end }}
        {{- end }}

            res, err := r.inner{{ .FuncName }}GraphQL(ctx, args)

            // event record
            if r.ext.recorder != nil {
            {{- if (isprimaryindex .) }}
                if err := r.ext.recorder.RecordEvent(ctx, "{{ plural $.Name }}", "Get", res); err != nil {
                    r.ext.logger.Warnf("unable to record event, resource:{{ plural $.Name }}, action:Get, err:%v", err)
                }
            {{- else }}
                if err := r.ext.recorder.RecordEvent(ctx, "{{ plural $.Name }}.{{ .FuncName }}", "NonPrimaryKeyGet", res); err != nil {
                    r.ext.logger.Warnf("unable to record event, resource:{{ plural $.Name }}.{{ .FuncName }}, action:NonPrimaryKeyGet, err:%v", err)
                }
            {{- end }}
            }
            return res, err
        }

    // inner{{ .FuncName }}GraphQL retrieves a row from '{{ $table }}' as a {{ .Type.Name }}.
    // Generated from index '{{ .Index.IndexName }}'.
    func (r *RootResolver) inner{{ .FuncName }}GraphQL(ctx context.Context, args struct{ 
        {{- range .Fields }}
            {{ .Name }} {{ sqltogotype .Type .Col.IsPrimaryKey }}
        {{- end -}}
        }) ({{ if not .Index.IsUnique }}*[]{{ else }}*{{ end }}{{ .Type.Name }}Resolver, error) {

        {{ range $index, $field := .Fields }}
        {{ if eq .Type "int" -}}
            arg{{ $index }}, err := strconv.Atoi(string(args.{{ .Name }}))
            if err != nil {
                return nil, errors.Wrap(err, `{{ .Name }} should be integer`)
            }
        {{ else if eq .Type "sql.NullString" -}}
            arg{{ $index }} := StringPointer(args.{{ .Name }})
        {{ else if eq .Type "int64" -}}
            arg{{ $index }}, err := strconv.ParseInt(string(args.{{ .Name }}), 10, 64)
            if err != nil {
                return nil, errors.Wrap(err, `{{ .Name }} should be int64`)
            }
        {{ else if eq .Type "string" -}}
            arg{{ $index }} := args.{{ .Name }}
        {{ else if eq .Type "sql.NullInt64" -}}
            if args.{{.Name}} == nil {
                return nil, nil
            }
            n, err := strconv.ParseInt(*args.{{.Name}}, 10, 64)
            if err != nil {
                return nil, errors.Wrap(err, `{{ .Name }} should be int64`)
            }
            arg{{ $index }} := sql.NullInt64{Int64: n, Valid: true}
        {{ else }}
            panic(`fix me in xo template extension.go.tpl for {{.Type}}`)
        {{- end }}
        {{ end }}

            data, err := r.ext.storage.{{ .FuncName }}(r.ext.db, 
            {{- range $index, $field := .Fields -}}
                arg{{ $index }},
            {{- end -}})
            if err != nil {
                if err == sql.ErrNoRows {
                    return nil, errors.Errorf(`{{ $.Table.TableName }} [`
                            {{- range $index, $field := .Fields -}}
                                {{- if eq $index 0 -}}
                                + "%v" 
                                {{- else -}}
                                + " %v" 
                                {{- end -}}
                            {{- end -}}
                            +`] not found`
                            {{- range $index, $field := .Fields -}}
                                ,arg{{ $index }}
                            {{- end -}})
                }
                return nil, errors.Wrap(err, `unable to get {{ $table }}`)
            }

        {{ if .Index.IsUnique }}
            return New{{ .Type.Name }}Resolver( data, r.ext), nil
        {{ else }}
            ret := make([]{{ .Type.Name }}Resolver, len(data))
            for i, row := range data {
		        ret[i] = {{ .Type.Name }}Resolver{ext: r.ext, node: row}
            }
            return &ret, nil
        {{ end }}
    }

    {{- end }}


    // {{ .Name }}ConnectionResolver defines a GraphQL resolver for {{ .Name }}Connection
    type {{ .Name }}ConnectionResolver struct {
        ext resolverExtensions

        data  []*{{ .Name }}
        count int32
    }

    // New{{ .Name }}ConnectionResolver return a GraphQL resolver for {{ .Name }}Connection
    func New{{ .Name }}ConnectionResolver(data []*{{ .Name }}, count int, ext resolverExtensions) *{{ .Name }}ConnectionResolver{
        return &{{ .Name }}ConnectionResolver{
            ext:   ext,
            data:  data,
            count: int32(count),
        }
    }

    // PageInfo returns PageInfo
    func (r {{ .Name }}ConnectionResolver) PageInfo() *PageInfoResolver {
        if len(r.data) == 0 {
            return &PageInfoResolver{}
        }

        return &PageInfoResolver{
            startCursor:     encodeCursor("{{ .Name }}", int(r.data[0].{{ .PrimaryKey.Name }})),
            endCursor:       encodeCursor("{{ .Name }}", int(r.data[len(r.data)-1].{{ .PrimaryKey.Name }})),
            hasNextPage:     false, // TODO
            hasPreviousPage: false, // TODO
        }
    }

    // Edges returns standard GraphQL edges
    func (r {{ .Name }}ConnectionResolver) Edges() *[]*{{ .Name }}EdgeResolver {
        edges := make([]*{{ .Name }}EdgeResolver, len(r.data))

        for i := range r.data {
            edges[i] = New{{ .Name }}EdgeResolver(r.data[i], r.ext)
        }
        return &edges
    }

    // TotalCount returns total count
    func (r {{ .Name }}ConnectionResolver) TotalCount() *int32 {
        return &r.count
    }

    // {{ plural .Name }} returns the list of {{ .Name }}
    func (r {{ .Name }}ConnectionResolver) {{ plural .Name }}() *[]*{{ .Name }}Resolver {
        data := make([]*{{ .Name }}Resolver, len(r.data))
        for i := range r.data {
            data[i] = New{{ .Name }}Resolver(r.data[i], r.ext)
        }
        return &data
    }

    // {{ .Name }}EdgeResolver defines the {{ .Name }} edge
    type {{ .Name }}EdgeResolver struct {
        ext resolverExtensions
        node *{{ .Name }}
    }

    // New{{ .Name }}EdgeResolver return a GraphQL resolver for {{ .Name }}EdgeResolver
    func New{{ .Name }}EdgeResolver(node *{{ .Name }}, ext resolverExtensions) *{{ .Name }}EdgeResolver{
        return &{{ .Name }}EdgeResolver{
            ext:  ext,
            node: node,
        }
    }

    // Node returns the {{ .Name }} node
    func (r {{ .Name }}EdgeResolver) Node() *{{ .Name }}Resolver {
        return New{{ .Name }}Resolver(r.node, r.ext)
    }

    // Cursor returns the cursor
    func (r {{ .Name }}EdgeResolver) Cursor() graphql.ID {
        return encodeCursor("{{ .Name }}", int(r.node.{{ .PrimaryKey.Name }}))
    }

    // Insert{{ .Name }}Input defines the insert {{ .Name }} mutation input
    type Insert{{ .Name }}Input struct {
    {{- range .Fields -}}
        {{- if ( or ($.Table.ManualPk) (ne .Name $.PrimaryKey.Name) ) }}
            {{ .Name }} {{ sqltogotype .Type .Col.IsPrimaryKey }}
        {{- end -}}
    {{- end }}
    }

    // Update{{ .Name }}Input defines the update {{ .Name }} mutation input
    type Update{{ .Name }}Input struct {
    {{- range .Fields }}
            {{ .Name }} {{ sqltogotype (sqlniltype .Type) .Col.IsPrimaryKey }}
    {{- end }}
            updateArguments
    }

    // Delete{{ .Name }}Input defines the delete {{ .Name }} mutation input
    type Delete{{ .Name }}Input struct {
    {{- range .Fields -}}
        {{- if eq .Name $.PrimaryKey.Name }}
            {{ .Name }} {{ sqltogotype .Type .Col.IsPrimaryKey }}
        {{- end -}}
    {{- end }}
    }

    // All{{ plural .Name }} is a graphQL endpoint of All{{ plural .Name }}
    func (r *RootResolver) All{{ plural .Name }}(ctx context.Context, args *{{ .Name }}QueryArguments) (*{{ .Name }}ConnectionResolver, error) {
    {{- if (enableac) }}
        if r.ext.verifier == nil {
            return nil, errors.New("enable ac, please set verifier")
        }
        if err := r.ext.verifier.VerifyAC(ctx, "{{ plural .Name }}", "GetAll", args); err != nil {
            return nil, errors.Wrap(err, "{{ plural .Name }}:GetAll")
        }
    {{- end }}

        res, err := r.all{{ plural .Name }}(ctx, args)

        // event record
        if r.ext.recorder != nil{
            if err := r.ext.recorder.RecordEvent(ctx, "{{ plural .Name }}", "GetAll", res); err != nil {
                r.ext.logger.Warnf("unable to record event, resource:{{ plural .Name }}, action:GetAll, err:%v", err)
            }
        }
        return res, err
    }

    func (r *RootResolver) all{{ plural .Name }}(ctx context.Context, queryArgs *{{ .Name }}QueryArguments) (*{{ .Name }}ConnectionResolver, error) {
        if queryArgs != nil && (queryArgs.After != nil || queryArgs.First != nil || queryArgs.Before != nil || queryArgs.Last != nil) {
            return nil, errors.New("not implemented yet, use offset + limit for pagination")
        }

        queryArgs = Apply{{ .Name }}QueryArgsDefaults(queryArgs)
    {{ if (existsqlfilter .) }}
        filterArgs, err := get{{ .Name }}Filter(queryArgs.Where)
        if err != nil {
            return nil, errors.Wrap(err, "unable to get {{ .Name }} filter")
        }
        queryArgs.filterArgs = filterArgs
    {{ end }}
        all{{ .Name }}, err := r.ext.storage.GetAll{{ .Name }}(r.ext.db, queryArgs)
        if err != nil {
            return nil, errors.Wrap(err, "unable to get {{ .Name }}")
        }

        count, err := r.ext.storage.CountAll{{ .Name }}(r.ext.db, queryArgs)
        if err != nil {
            return nil, errors.Wrap(err, "unable to get count")
        }

        return &{{ .Name }}ConnectionResolver{
            ext:   r.ext,
            data:  all{{ .Name }},
            count: int32(count),
        }, nil
    }

    // Insert{{ plural .Name }} is a graphQL endpoint of Insert{{ plural .Name }}
    func (r *RootResolver) Insert{{ plural .Name  }}(ctx context.Context, args struct{ Input []Insert{{ .Name }}Input }) ([]{{ .Name }}Resolver, error) {
    {{- if (enableac) }}
        if r.ext.verifier == nil {
            return nil, errors.New("enable ac, please set verifier")
        }
        if err := r.ext.verifier.VerifyAC(ctx, "{{ plural .Name }}", "Insert", args); err != nil {
            return nil, errors.Wrap(err, "{{ plural .Name }}:Insert")
        }
    {{- end }}

        res, err := r.insert{{ .Name  }}GraphQL(ctx, args.Input)

        // event record
        if r.ext.recorder != nil{
            if err := r.ext.recorder.RecordEvent(ctx, "{{ plural .Name }}", "Insert", res); err != nil {
                r.ext.logger.Warnf("unable to record event, resource:{{ plural .Name }}, action:Insert, err:%v", err)
            }
        }
        return res, err
    }

    func (r *RootResolver) insert{{ .Name }}GraphQL(ctx context.Context, items []Insert{{ .Name }}Input) ([]{{ .Name }}Resolver, error) {
        results := make([]{{ .Name }}Resolver, len(items))
        for i := range items {
            input := items[i]
            {{ range $index, $field := .Fields -}}
                {{ $it := (sqltogotype .Type .Col.IsPrimaryKey) }}
                {{ if (and .Col.IsPrimaryKey (not $.Table.ManualPk)) }}
                    {{/* primary key column skipped */}}
                {{- else if (and (eq $it "graphql.ID") (eq .Type "int64")) -}}
                    {{ print "f" $index }}, err := strconv.ParseInt(string({{ gotosql .Type (print "input." .Name) }}), 10, 0)
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be an integer")
                    }
                {{ else if (eq $it "graphql.ID") -}}
                    {{ print "f" $index }}, err := strconv.Atoi(string({{ gotosql .Type (print "input." .Name) }}))
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be an integer")
                    }
                {{- else if (and (eq $it "*string") (eq .Type "sql.NullInt64")) -}}
                    var {{ print "f" $index }} sql.NullInt64
                    if {{ print "input." .Name }} != nil {
                        n, err := strconv.ParseInt(*{{ print "input." .Name }}, 10, 0)
                        if err != nil {
                            return nil, errors.New("{{ .Name }} must be an integer")
                        }
                        {{ print "f" $index }} = sql.NullInt64{Int64: n, Valid: true}
                    }
                {{- else if (and (eq $it "*string") (eq .Type "decimal.NullDecimal")) -}}
                    var {{ print "f" $index }} decimal.NullDecimal
                    if {{ print "input." .Name }} != nil {
                        dec, err := decimal.NewFromString(*{{ print "input." .Name }})
                        if err != nil {
                            return nil, errors.New("{{ .Name }} must be a decimal")
                        }
                        
                        {{ print "f" $index }} = decimal.NullDecimal{
                            Decimal: dec,
                            Valid: true,
                        }
                    }
                {{- else if (and (eq $it "string") (eq .Type "decimal.Decimal")) -}}
                    {{ print "f" $index }}, err := decimal.NewFromString({{ print "input." .Name }})
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be a decimal")
                    }
                {{- else if (and (eq $it "string") (eq .Type "int64")) -}}
                    {{ print "f" $index }}, err := strconv.ParseInt({{ gotosql .Type (print "input." .Name) }}, 10, 0)
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be an integer")
                    }
                {{- else if (and (eq $it "string") (eq .Type "int")) -}}
                    {{ print "f" $index }}, err := strconv.Atoi({{ gotosql .Type (print "input." .Name) }})
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be an integer")
                    }
                {{- else -}}
                    {{ print "f" $index }} := {{ gotosql .Type (print "input." .Name) }}
                {{- end -}}
            {{ end }}
            node:= &{{ .Name }}{
                {{- range $index, $field := .Fields -}}
                    {{- if ( or ($.Table.ManualPk) (ne .Name $.PrimaryKey.Name) ) -}}
                        {{ .Name }}: {{ print "f" $index }},
                    {{- end }}
                {{ end }}
            }
            if err := r.ext.storage.Insert{{ .Name }}ByFields(r.ext.db, node); err != nil {
                return nil, errors.Wrap(err, "unable to insert {{ .Name }}")
            }
            results[i] = {{ .Name }}Resolver{ ext: r.ext, node: node }
        }
        return results, nil
    }

    // Update{{ .Name }}GraphQL is the GraphQL end point for Update{{ .Name }}
    func (r *RootResolver) Update{{ plural .Name  }}(ctx context.Context, args struct{ Input []Update{{ .Name }}Input }) ([]{{ .Name }}Resolver, error) {
    {{- if (enableac) }}
        if r.ext.verifier == nil {
            return nil, errors.New("enable ac, please set verifier")
        }
        if err := r.ext.verifier.VerifyAC(ctx, "{{ plural .Name }}", "Update", args); err != nil {
            return nil, errors.Wrap(err, "{{ plural .Name }}:Update")
        }
    {{- end }}

        res, err := r.update{{ .Name  }}GraphQL(ctx, args.Input)

        // event record
        if r.ext.recorder != nil {
            if err := r.ext.recorder.RecordEvent(ctx, "{{ plural .Name }}", "Update", res); err != nil {
                r.ext.logger.Warnf("unable to record event, resource:{{ plural .Name }}, action:Update, err:%v", err)
            }
        }
        return res, err
    }

    func (r *RootResolver) update{{ .Name }}GraphQL(ctx context.Context, items []Update{{ .Name }}Input) ([]{{ .Name }}Resolver, error) {
        results := make([]{{ .Name }}Resolver, len(items))
        for i := range items {
            input := items[i]
            {{ if (eq .PrimaryKey.Type "int64") -}}
                id, err := strconv.ParseInt(string(input.{{ .PrimaryKey.Name }}), 10, 64)
            {{ else if (eq .PrimaryKey.Type "int") -}}
                id, err := strconv.Atoi(string(input.{{ .PrimaryKey.Name }}))
            {{ else -}}
                panic("unhandled pk type {{ .Name }}.{{ .PrimaryKey.Name }} from {{ .PrimaryKey.Type }}")
            {{ end -}}
            if err != nil {
                return nil, errors.New("{{ .PrimaryKey.Name }} must be an integer")
            }

            {{ $length := minus (len .Fields) 1 }}
            {{ $sn := shortname .Name }}
            node := &{{ .Name }}{ {{ .PrimaryKey.Name }}: id}
            fields := make([]string, 0, {{ $length }})
            params := make([]interface{}, 0, {{ $length }})
            retCols := make([]string, 0, {{ $length }})
            retVars := make([]interface{}, 0, {{ $length }})

            {{- range $index, $field := .Fields -}}
                {{ if (not $field.Col.IsPrimaryKey) }}
                    {{ if (eq $field.Type "string") }}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            return nil, errors.New("couldn't set {{ togqlname $field.Name }} to null")
                        }
                        if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            node.{{ $field.Name }} = *input.{{ $field.Name }}
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "int") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            return nil, errors.New("couldn't set {{ togqlname $field.Name }} to null")
                        }
                        if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            if n, err := strconv.Atoi(*input.{{ $field.Name }}); err != nil {
                                return nil, errors.New("{{ $field.Name }} must be an integer")
                            } else { node.{{ $field.Name }} = n }
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "int64") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            return nil, errors.New("couldn't set {{ togqlname $field.Name }} to null")
                        }
                        if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            if n, err := strconv.ParseInt(*input.{{ $field.Name }}, 10, 64); err != nil {
                                return nil, errors.New("{{ $field.Name }} must be an integer")
                            } else { node.{{ $field.Name }} = n }
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "bool") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            return nil, errors.New("couldn't set {{ togqlname $field.Name }} to null")
                        }
                        if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            node.{{ $field.Name }} = *input.{{ $field.Name }}
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "decimal.Decimal") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            return nil, errors.New("couldn't set {{ togqlname $field.Name }} to null")
                        }
                        if input.{{ $field.Name }} != nil {
                            if n, err := decimal.NewFromString(*input.{{ $field.Name }}); err != nil {
                                return nil, errors.New("{{ $field.Name }} must be a decimal")
                            } else {
                                fields = append(fields, `{{ (colname $field.Col) }}`)
                                params = append(params, n)
                                node.{{ $field.Name }} = n
                            }
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "decimal.NullDecimal") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, decimal.NullDecimal{})
                            node.{{ $field.Name }} = decimal.NullDecimal{}
                        } else if input.{{ $field.Name }} != nil {
                            if n, err := decimal.NewFromString(*input.{{ $field.Name }}); err != nil {
                                return nil, errors.New("{{ $field.Name }} must be a decimal")
                            } else {
                                fields = append(fields, `{{ (colname $field.Col) }}`)
                                params = append(params, n)
                                node.{{ $field.Name }} = decimal.NullDecimal{Decimal: n, Valid: true}
                            }
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "time.Time") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            return nil, errors.New("couldn't set {{ togqlname $field.Name }} to null")
                        }
                        if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            node.{{ $field.Name }} = input.{{ $field.Name }}.Time
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "NullTime") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, NullTime{})
                            node.{{ $field.Name }} = NullTime{}
                        } else if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, input.{{ $field.Name }}.Time)
                            node.{{ $field.Name }} = NullTime{Time:input.{{ $field.Name }}.Time,Valid: true}
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "sql.NullInt64") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, sql.NullInt64{})
                            node.{{ $field.Name }} = sql.NullInt64{}
                        } else if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            if n, err := strconv.ParseInt(*input.{{ $field.Name }}, 10, 64); err != nil {
                                return nil, errors.New("{{ $field.Name }} must be an integer")
                            else { node.{{ $field.Name }} = sql.NullInt64{Int64: n, Valid: true} }
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "sql.NullString") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, sql.NullString{})
                            node.{{ $field.Name }} = sql.NullString{}
                        } else if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            node.{{ $field.Name }} = sql.NullString{String: *input.{{ $field.Name }}, Valid: true}
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "sql.NullBool") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, sql.NullBool{})
                            node.{{ $field.Name }} = sql.NullBool{}
                        } else if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            node.{{ $field.Name }} = sql.NullBool{Bool: *input.{{ $field.Name }}, Valid: true}
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else if (eq $field.Type "sql.NullFloat64") -}}
                        if isDeletionFields(input.Deletions, "{{ togqlname $field.Name }}") {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, sql.NullFloat64{})
                            node.{{ $field.Name }} = sql.NullFloat64{}
                        } else if input.{{ $field.Name }} != nil {
                            fields = append(fields, `{{ (colname $field.Col) }}`)
                            params = append(params, *input.{{ $field.Name }})
                            node.{{ $field.Name }} = sql.NullFloat64{Float64: *input.{{ $field.Name }}, Valid: true}
                        } else {
                            retCols = append(retCols, `{{ (colname $field.Col) }}`)
                            retVars = append(retVars, &node.{{ $field.Name }})
                        }
                    {{ else -}}
                        panic("unhandled {{ .Name }}.{{ $field.Name }} from {{ $field.Type }}")
                    {{ end -}}
                {{ end -}}
            {{ end -}}
            if len(params) == 0 {
                return nil, errors.New("all fields are empty, unable to update")
            }

            if err := r.ext.storage.Update{{ .Name }}ByFields(r.ext.db, node, fields, retCols, params, retVars); err != nil {
                if err == sql.ErrNoRows {
                    return nil, errors.Errorf(`{{ .Name }} [%d] not found`, node.{{ .PrimaryKey.Name }})
                }
                return nil, err
            }

            results[i] = {{ .Name }}Resolver{ ext: r.ext, node: node }
        }
        return results, nil
    }

    // Delete{{ .Name }}GraphQL is the GraphQL end point for Delete{{ .Name }}
    func (r *RootResolver) Delete{{ plural .Name  }}(ctx context.Context, args struct{ Input []Delete{{ .Name }}Input }) ([]graphql.ID, error) {
    {{- if (enableac) }}
        if r.ext.verifier == nil {
            return nil, errors.New("enable ac, please set verifier")
        }
        if err := r.ext.verifier.VerifyAC(ctx, "{{ plural .Name }}", "Delete", args); err != nil {
            return nil, errors.Wrap(err, "{{ plural .Name }}:Delete")
        }
    {{- end }}

        res, err := r.delete{{ .Name  }}GraphQL(ctx, args.Input)

        // event record
        if r.ext.recorder != nil {
            if err := r.ext.recorder.RecordEvent(ctx, "{{ plural .Name }}", "Delete", res); err != nil {
                r.ext.logger.Warnf("unable to record event, resource:{{ plural .Name }}, action:Delete, err:%v", err)
            }
        }
        return res, err
    }

    func (r *RootResolver) delete{{ .Name }}GraphQL(ctx context.Context, items []Delete{{ .Name }}Input) ([]graphql.ID, error) {
        results := make([]graphql.ID, len(items))
        inputs := make([]*{{ .Name }}, len(items))

        for i := range items {
            input := items[i]
            {{ range $index, $field := .Fields -}}
                {{ $it := (sqltogotype .Type .Col.IsPrimaryKey) }}
                {{ if (not .Col.IsPrimaryKey) }}
                {{ else if (and (eq $it "graphql.ID") (eq .Type "int")) -}}
                    id, err := strconv.Atoi(string({{ gotosql .Type (print "input." .Name) }}))
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be an integer")
                    }
                {{- else if (and (eq $it "graphql.ID") (eq .Type "int64")) -}}
                    id, err := strconv.ParseInt(string({{ gotosql .Type (print "input." .Name) }}), 10, 0)
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be an integer")
                    }
                {{- else if (and (eq $it "*string") (eq .Type "sql.NullInt64")) -}}
                    var id sql.NullInt64
                    if {{ print "input." .Name }} != nil {
                        n, err := strconv.ParseInt(*{{ print "input." .Name }}, 10, 0)
                        if err != nil {
                            return nil, errors.New("{{ .Name }} must be an integer")
                        }
                        id = sql.NullInt64{Int64: n, Valid: true}
                    }
                {{- else if (and (eq $it "string") (eq .Type "int64")) -}}
                    id, err := strconv.ParseInt({{ gotosql .Type (print "input." .Name) }}, 10, 0)
                    if err != nil {
                        return nil, errors.New("{{ .Name }} must be an integer")
                    }
                {{- else -}}
                    id := {{ gotosql .Type (print "input." .Name) }}
                {{- end -}}
            {{ end }}

            results[i] = input.{{ .PrimaryKey.Name }}
            inputs[i] = &{{ .Name }}{ {{ .PrimaryKey.Name }}: id}
        }


        err := r.ext.storage.Delete{{ .Name }}s(r.ext.db, inputs)
        if err != nil {
            return nil, err
        }

        return results, nil
    }

    {{ if (enableac) }}
        func (r *RootResolver) get{{ .Name }}GraphQLResources() []GraphQLResource {
            return []GraphQLResource{
                GraphQLResource{
                    Name:     "{{ plural .Name }}",
                    Describe: "This is a graphQL resource {{ plural .Name }}, have GetAll, Get, Insert, Update, Delete actions.",
                },
            {{- range $x := .Indexes }}
                {{- if not (isprimaryindex .) }}
                GraphQLResource{
                    Name:     "{{ plural $.Name }}.{{ .FuncName }}",
                    Describe: "This is a graphQL resource {{ plural $.Name }}.{{ .FuncName }}, only have NonPrimaryKeyGet action.",
                },
                {{- end }}
            {{- end }}
            {{- range .Fields -}}
                {{- if (and (isacfield $table .) (enableac)) }}
                // only the field is defined in ExtraACRules declared in file extra_rules.yaml
                GraphQLResource{
                    Name:     "{{ plural $.Name }}.{{ .Name }}",
                    Describe: "This is a graphQL resource {{ plural $.Name }}.{{ .Name }}, effected on field {{ .Name }}, only have Get action",
                },
                {{- end }}
            {{- end }}
            }
        }
    {{- end }}
{{- end }}
