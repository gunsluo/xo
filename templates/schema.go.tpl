{{- $iname := "Storage" -}}
// {{ $iname }} is interface structure for database operation that can be called
type {{ $iname }} interface {
{{- range .Tables }}
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "xoLog") -}}
    {{- $t := . -}}
    {{- $table := (schema .Table.TableName) -}}
    {{- if .PrimaryKey }}
    // Insert{{ .Name }} inserts the {{ .Name }} to the database.
    Insert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    // Insert{{ .Name }}ByFields inserts the {{ .Name }} to the database.
    Insert{{ .Name }}ByFields(db XODB, {{ $short }} *{{ .Name }}) error
    // Delete{{ .Name }} deletes the {{ .Name }} from the database.
    Delete{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    // Delete{{ .Name }}s deletes the {{ .Name }} from the database.
    Delete{{ .Name }}s(db XODB, {{ $short }} []*{{ .Name }}) error
    {{- if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
        // Update updates the {{ .Name }} in the database.
        Update{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Update{{ .Name }}ByFields updates the {{ .Name }} in the database.
        Update{{ .Name }}ByFields(db XODB, {{ $short }} *{{ .Name }}, fields, retCols []string, params, retVars []interface{}) error
        // Save saves the {{ .Name }} to the database.
        Save{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Upsert performs an upsert for {{ .Name }}.
        Upsert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    {{- else }}
        // Update statements omitted due to lack of fields other than primary key
    {{- end }}
    {{- end }}
    // GetMostRecent{{ .Name }} returns n most recent rows from '{{ .Table.TableName }}',
    // ordered by "created_date" in descending order.
    GetMostRecent{{ .Name }}(db XODB, n int) ([]*{{ .Name }}, error)
    // GetMostRecentChanged{{ .Name }} returns n most recent rows from '{{ .Table.TableName }}',
    // ordered by "changed_date" in descending order.
    GetMostRecentChanged{{ .Name }}(db XODB, n int) ([]*{{ .Name }}, error)
    // GetAll{{ .Name }} returns all rows from '{{ .Table.TableName }}', based on the {{ .Name }}QueryArguments.
    // If the {{ .Name }}QueryArguments is nil, it will use the default {{ .Name }}QueryArguments instead.
    GetAll{{ .Name }}(db XODB, queryArgs *{{ .Name }}QueryArguments) ([]*{{ .Name }}, error)
    // CountAll{{ .Name }} returns a count of all rows from '{{ .Table.TableName }}'
    CountAll{{ .Name }}(db XODB, queryArgs *{{ .Name }}QueryArguments) (int, error)
    {{- range .ForeignKeys }}
	    {{- $fnname := (print (plural $t.Name) "By" .Field.Name "FK") -}}
	    {{- if not (isdup $fnname "interface") }}
            // {{ $fnname }} retrieves rows from {{ $table }} by foreign key {{.Field.Name}}.
            // Generated from foreign key {{.Name}}.
            {{ $fnname }}(db XODB, {{ togqlname .Field.Name }} {{ .RefField.Type }}, queryArgs *{{ $t.Name }}QueryArguments) ([]*{{$t.Name}}, error)
            // Count{{ $fnname }} count rows from {{ $table }} by foreign key {{.Field.Name}}.
            // Generated from foreign key {{.Name}}.
            Count{{ $fnname }}(db XODB, {{ togqlname .Field.Name }} {{ .RefField.Type }}, queryArgs *{{ $t.Name }}QueryArguments) (int, error)
	    {{- end }}
    {{- end }}
{{- end }}

{{- range .Views }}
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "xoLog") -}}
    {{- $t := . -}}
    {{- $table := (schema .Table.TableName) -}}
    {{- if .PrimaryKey }}
    // Insert{{ .Name }} inserts the {{ .Name }} to the database.
    Insert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    // Insert{{ .Name }}ByFields inserts the {{ .Name }} to the database.
    Insert{{ .Name }}ByFields(db XODB, {{ $short }} *{{ .Name }}}) error
    // Delete{{ .Name }} deletes the {{ .Name }} from the database.
    Delete{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    // Delete{{ .Name }}s deletes the {{ .Name }} from the database.
    Delete{{ .Name }}s(db XODB, {{ $short }} []*{{ .Name }}) error
    {{- if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
        // Update updates the {{ .Name }} in the database.
        Update{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Update{{ .Name }}ByFields updates the {{ .Name }} in the database.
        Update{{ .Name }}ByFields(db XODB, {{ $short }} *{{ .Name }}, fields, retCols []string, params, retVars []interface{}) error
        // Save saves the {{ .Name }} to the database.
        Save{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
        // Upsert performs an upsert for {{ .Name }}.
        Upsert{{ .Name }}(db XODB, {{ $short }} *{{ .Name }}) error
    {{- else }}
        // Update statements omitted due to lack of fields other than primary key
    {{- end }}
    {{- end }}
    // GetMostRecent{{ .Name }} returns n most recent rows from '{{ .Table.TableName }}',
    // ordered by "created_date" in descending order.
    GetMostRecent{{ .Name }}(db XODB, n int) ([]*{{ .Name }}, error)
    // GetMostRecentChanged{{ .Name }} returns n most recent rows from '{{ .Table.TableName }}',
    // ordered by "changed_date" in descending order.
    GetMostRecentChanged{{ .Name }}(db XODB, n int) ([]*{{ .Name }}, error)
    // GetAll{{ .Name }} returns all rows from '{{ .Table.TableName }}', based on the {{ .Name }}QueryArguments.
    // If the {{ .Name }}QueryArguments is nil, it will use the default {{ .Name }}QueryArguments instead.
    GetAll{{ .Name }}(db XODB, queryArgs *{{ .Name }}QueryArguments) ([]*{{ .Name }}, error)
    // CountAll{{ .Name }} returns a count of all rows from '{{ .Table.TableName }}'
    CountAll{{ .Name }}(db XODB, queryArgs *{{ .Name }}QueryArguments) (int, error)
    {{- range .ForeignKeys }}
	    {{- $fnname := (print (plural $t.Name) "By" .Field.Name "FK") -}}
	    {{- if not (isdup $fnname "interface") }}
            // {{ $fnname }} retrieves rows from {{ $table }} by foreign key {{.Field.Name}}.
            // Generated from foreign key {{.Name}}.
            {{ $fnname }}(db XODB, {{ togqlname .Field.Name }} {{ .RefField.Type }}, queryArgs *{{ $t.Name }}QueryArguments) ([]*{{$t.Name}}, error)
            // Count{{ $fnname }} count rows from {{ $table }} by foreign key {{.Field.Name}}.
            // Generated from foreign key {{.Name}}.
            Count{{ $fnname }}(db XODB, {{ togqlname .Field.Name }} {{ .RefField.Type }}, queryArgs *{{ $t.Name }}QueryArguments) (int, error)
	    {{- end }}
    {{- end }}
{{- end }}

{{- range .Foreign }}
    {{- $short := (shortname .Type.Name) }}
    // {{ .Name }}In{{ .Type.Name }} returns the {{ .RefType.Name }} associated with the {{ .Type.Name }}'s {{ .Field.Name }} ({{ .Field.Col.ColumnName }}).
    // Generated from foreign key '{{ .ForeignKey.ForeignKeyName }}'.
    {{ .Name }}In{{ .Type.Name }}(db XODB, {{ $short }} *{{ .Type.Name }}) (*{{ .RefType.Name }}, error)
{{- end }}

{{- range .Indexes }}
    {{- $table := (schema .Schema .Type.Table.TableName) }}
    // {{ .FuncName }} retrieves a row from '{{ $table }}' as a {{ .Type.Name }}.
    // Generated from index '{{ .Index.IndexName }}'.
    {{ .FuncName }}(db XODB{{ goparamlist .Fields true true }}) ({{ if not .Index.IsUnique }}[]{{ end }}*{{ .Type.Name }}, error)
{{- end }}
}

{{ range .Drivers }}
    {{ $udriver := (firstletterupper .) }}
    // {{ $udriver }}{{ $iname }} is {{ $udriver }} for the database.
    type {{ $udriver }}{{ $iname }} struct {
	    logger XOLogger
    }

    func (s *{{ $udriver }}{{ $iname }}) info(format string, args ...interface{}) {
        if len(args) == 0 {
            xoLog(s.logger, logrus.InfoLevel, format)
        } else {
            xoLogf(s.logger, logrus.InfoLevel, "%s %v", format, args)
        }
    }
{{- end }}

// New is a construction method that return a new Storage
func New(driver string, c Config) (Storage, error) {
	// fix bug which interface type is not nil and interface value is nil
	var logger XOLogger
	if c.Logger != nil && !(reflect.ValueOf(c.Logger).Kind() == reflect.Ptr && reflect.ValueOf(c.Logger).IsNil()) {
		logger = c.Logger
	}

	var s Storage
	switch driver {
{{- range .Drivers }}
    {{- $driver := . -}}
    {{- $udriver := (firstletterupper $driver) }}
	case "{{ $driver }}":
		s = &{{ $udriver }}{{ $iname }}{ logger: logger }
{{- end }}
	default:
		return nil, errors.New("driver " + driver + " not support")
	}

	return s, nil
}

{{ range .Tables }}
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "xoLog") -}}
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
    {{- $short := (shortname .Name "err" "res" "sqlstr" "db" "xoLog") -}}
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


// extension block
{{- if (enableextension) }}
    // GraphQL extension

    // GraphQL related types
    const GraphQLCommonTypes = `
        type PageInfo {
            hasNextPage: Boolean!
            hasPreviousPage: Boolean!
            startCursor: ID
            endCursor: ID
        }
        scalar Time
        enum FilterConjunction{
            AND
            OR
        }
    `

    // PageInfoResolver defines the GraphQL PageInfo type
    type PageInfoResolver struct {
        startCursor     graphql.ID
        endCursor       graphql.ID
        hasNextPage     bool
        hasPreviousPage bool
    }

    // StartCursor returns the start cursor (global id)
    func (r *PageInfoResolver) StartCursor() *graphql.ID {
        return &r.startCursor
    }

    // EndCursor returns the end cursor (global id)
    func (r *PageInfoResolver) EndCursor() *graphql.ID {
        return &r.endCursor
    }

    // HasNextPage returns if next page is available
    func (r *PageInfoResolver) HasNextPage() bool {
        return r.hasNextPage
    }

    // HasPreviousPage returns if previous page is available
    func (r *PageInfoResolver) HasPreviousPage() bool {
        return r.hasNextPage
    }

    // ResolverConfig is a config for Resolver
    type ResolverConfig struct {
        Logger   XOLogger
        DB       XODB
        S        Storage
        Recorder EventRecorder
    {{- if (enableac) }}
        Verifier Verifier
    {{- end }}
    }

    // resolverExtensions it's passing between root resolver and  children resolver
    type resolverExtensions struct {
        logger   XOLogger
        db       XODB
        storage  Storage
        recorder EventRecorder
    {{- if (enableac) }}
        verifier Verifier
    {{- end }}
    }

    // RootResolver is a graphql root resolver
    type RootResolver struct {
        ext resolverExtensions
    }

    // NewRootResolver return a root resolver for ggraphql
    func NewRootResolver(c *ResolverConfig) *RootResolver {
        logger := c.Logger
        if logger == nil {
            logger = logrus.New()
        }

        return &RootResolver{
            ext: resolverExtensions{
                logger:   logger,
                db:       c.DB,
                storage:  c.S,
                recorder: c.Recorder,
    {{- if (enableac) }}
                verifier: c.Verifier,
    {{- end }}
            },
        }
    }

    // BuildSchemaString build root schema string
    func (r *RootResolver) BuildSchemaString(extraQueries, extraMutations, extraTypes string) string {
        return `
        schema {
            query: Query
            mutation: Mutation
        }

        type Query {
    ` +  
    {{- range $type, $_ := .TypeMap }}
        r.Get{{ $type }}Queries() +
    {{- end -}}
        extraQueries +
    `}

    type Mutation {
    ` + 
    {{- range $type, $_ := .TypeMap }}
        r.Get{{ $type }}Mutations() +
    {{- end -}}
        extraMutations +
    `}

    ` + 
    {{- range $type, $_ := .TypeMap }}
        r.Get{{ $type }}Types() +
    {{- end }}
        GraphQLCommonTypes +
        extraTypes
    }

    func encodeCursor(typeName string, id int) graphql.ID {
        return graphql.ID(base64.StdEncoding.EncodeToString([]byte(fmt.Sprintf("%s:%d", typeName, id))))
    }

    // EventRecorder is event recorder
    type EventRecorder interface {
        RecordEvent(ctx context.Context, resource, action string, args interface{}) error
    }

    // Bool returns a nullable bool.
    func Bool(b bool) sql.NullBool {
        return sql.NullBool{Bool: b, Valid: true}
    }

    // BoolPointer converts bool pointer to sql.NullBool
    func BoolPointer(b *bool) sql.NullBool {
        if b == nil {
            return sql.NullBool{}
        }
        return sql.NullBool{Bool: *b, Valid: true}
    }

    // PointerBool converts bool to pointer to bool
    func PointerBool(b sql.NullBool) *bool {
        if !b.Valid {
            return nil
        }
        return &b.Bool
    }

    // NullDecimalString converts decimal.NullDecimal to *string
    func NullDecimalString(b decimal.NullDecimal) *string {
        if !b.Valid {
            return nil
        }
        x := b.Decimal.String()
        return &x
    }

    // Int64 returns a nullable int64
    func Int64(i int64) sql.NullInt64 {
        return sql.NullInt64{Int64: i, Valid: true}
    }

    // Int64Pointer converts a int64 pointer to sql.NullInt64
    func Int64Pointer(i *int64) sql.NullInt64 {
        if i == nil {
            return sql.NullInt64{}
        }
        return sql.NullInt64{Int64: *i, Valid: true}
    }

    // PointerInt64 converts sql.NullInt64 to pointer to int64
    func PointerInt64(i sql.NullInt64) *int64 {
        if !i.Valid {
            return nil
        }
        return &i.Int64
    }

    // Float64 returns a nullable float64
    func Float64(i float64) sql.NullFloat64 {
        return sql.NullFloat64{Float64: i, Valid: true}
    }

    // Float64Pointer converts a float64 pointer to sql.NullFloat64
    func Float64Pointer(i *float64) sql.NullFloat64 {
        if i == nil {
            return sql.NullFloat64{}
        }
        return sql.NullFloat64{Float64: *i, Valid: true}
    }

    // PointerFloat64 converts sql.NullFloat64 to pointer to float64
    func PointerFloat64(i sql.NullFloat64) *float64 {
        if !i.Valid {
            return nil
        }
        return &i.Float64
    }

    // String returns a nullable string
    func String(s string) sql.NullString {
        return sql.NullString{String: s, Valid: true}
    }

    // StringPointer converts string pointer to sql.NullString
    func StringPointer(s *string) sql.NullString {
        if s == nil {
            return sql.NullString{}
        }
        return sql.NullString{String: *s, Valid: true}
    }

    // PointerString converts sql.NullString to pointer to string
    func PointerString(s sql.NullString) *string {
        if !s.Valid {
            return nil
        }
        return &s.String
    }

    // Time returns a nullable Time
    func Time(t time.Time) NullTime {
        return NullTime{Time: t, Valid: true}
    }

    // TimePointer converts time.Time pointer to NullTime
    func TimePointer(t *time.Time) NullTime {
        if t == nil {
            return NullTime{}
        }
        return NullTime{Time: *t, Valid: true}
    }

    // TimeGqlPointer converts graphql.Time pointer to NullTime
    func TimeGqlPointer(t *graphql.Time) NullTime {
        if t == nil {
            return NullTime{}
        }
        return NullTime{Time: t.Time, Valid: true}
    }

    // PointerTime converts NullTIme to pointer to time.Time
    func PointerTime(t NullTime) *time.Time {
        if !t.Valid {
            return nil
        }
        return &t.Time
    }

    // PointerGqlTime converts NullType to pointer to graphql.Time
    func PointerGqlTime(t NullTime) *graphql.Time {
        if !t.Valid {
            return nil
        }
        return &graphql.Time{Time: t.Time}
    }

    // PointerStringInt64 converts Int64 pointer to string pointer
    func PointerStringInt64(i *int64) *string {
        if i == nil {
            return nil
        }
        s := strconv.Itoa(int(*i))
        return &s
    }

    // PointerStringSqlInt64 converts sql.NullInt64 pointer to graphql.ID pointer
    func PointerStringSqlInt64(i sql.NullInt64) *string {
        if !i.Valid {
            return nil
        }
        s := strconv.Itoa(int(i.Int64))
        return &s
    }

    // PointerStringFloat64 converts Float64 pointer to string pointer
    func PointerStringFloat64(i *float64) *string {
        if i == nil {
            return nil
        }
        s :=fmt.Sprintf("%.6f", *i)
        return &s
    }

    // PointerFloat64SqlFloat64 converts sql.NullFloat64 pointer to graphql.ID pointer
    func PointerFloat64SqlFloat64(i sql.NullFloat64) *float64 {
        if !i.Valid {
            return nil
        }
        s := i.Float64
        return &s
    }

    {{- if (enableac) }}
    // access control
    // Verifier is access control verifier
    type Verifier interface {
        VerifyAC(ctx context.Context, resource, action string, args interface{}) error
        VerifyRefAC(ctx context.Context, resource, action string, args interface{}) error
    }

    // GraphQLResource is a resource of graphql API
    type GraphQLResource struct {
        Name     string
        Describe string
    }

    // GetResolverResources get all resource  
    func (r *RootResolver) GetResolverResources(includes []GraphQLResource, excludes []string) ([]GraphQLResource, error) {
        uniqueResources := make(map[string]GraphQLResource)

        {{- range $type, $_ := .TypeMap }}
            for _, r := range r.get{{ $type }}GraphQLResources() {
                if v, ok := uniqueResources[r.Name]; ok {
                    return nil, errors.Errorf("duplicate resource %s", v.Name)
                } else {
                    uniqueResources[v.Name] = v
                }
            }
        {{- end }}

        for _, r := range includes {
            if v, ok := uniqueResources[r.Name]; ok {
                return nil, errors.Errorf("duplicate resource %s", v.Name)
            } else {
                uniqueResources[v.Name] = v
            }
        }

        for _, k := range excludes {
            delete(uniqueResources, k)
        }

        var resources []GraphQLResource
        for _, v := range uniqueResources {
            resources = append(resources, v)
        }

        return resources, nil
    }
    {{- end }}
{{- end }}
