package internal

import (
	"fmt"
	"strconv"
	"strings"
	"text/template"

	"github.com/gedex/inflector"
	"github.com/knq/snaker"
	"github.com/xo/xo/models"
)

// NewTemplateFuncs returns a set of template funcs bound to the supplied args.
func (a *ArgType) NewTemplateFuncs() template.FuncMap {
	return template.FuncMap{
		"colcount":             a.colcount,
		"colnames":             a.colnames,
		"colnamesas":           a.colnamesas,
		"colnamesmulti":        a.colnamesmulti,
		"colnamesquery":        a.colnamesquery,
		"colprefixnamesquery":  a.colprefixnamesquery,
		"colnamesquerymulti":   a.colnamesquerymulti,
		"colprefixnames":       a.colprefixnames,
		"colvals":              a.colvals,
		"colvalsmulti":         a.colvalsmulti,
		"collastvals":          a.collastvals,
		"colnumval":            a.colnumval,
		"fieldnames":           a.fieldnames,
		"fieldnamesmulti":      a.fieldnamesmulti,
		"goparamlist":          a.goparamlist,
		"reniltype":            a.reniltype,
		"retype":               a.retype,
		"shortname":            a.shortname,
		"convext":              a.convext,
		"schema":               a.schemafn,
		"colname":              a.colname,
		"parsecolname":         a.parsecolname,
		"hascolumn":            a.hascolumn,
		"hasfield":             a.hasfield,
		"getstartcount":        a.getstartcount,
		"driver":               a.driver,
		"firstletterupper":     a.firstLetterUpper,
		"fkname":               a.fkname,
		"fkreversefield":       a.fkreversefield,
		"getforeignkey":        a.getforeignkey,
		"gotosql":              a.gotosql,
		"plural":               a.plural,
		"singular":             a.singular,
		"sqltogotype":          a.sqltogotype,
		"sqltogoreturntype":    a.sqltogoreturntype,
		"sqltogql":             a.sqltogql,
		"sqltogqltype":         a.sqltogqltype,
		"togqlname":            a.togqlname,
		"islast":               a.islast,
		"sqlniltype":           a.sqlniltype,
		"isdup":                a.isdup,
		"sqltogopointertype":   a.sqltogopointertype,
		"sqltogqloptionaltype": a.sqltogqloptionaltype,
		"sqlfilter":            a.sqlfilter,
		"flatidxfields":        a.flatidxfields,
		"existsqlfilter":       a.existsqlfilter,
		"enableac":             a.enableAC,
		"enableextension":      a.enableExtension,
		"isacfield":            a.isACField,
		"isprimaryindex":       a.isPrimaryIndex,
		"groupindexedresource": a.groupIndexedResource,
		"minus":                a.minus,
		"mask":                 a.mask,
	}
}

// retype checks typ against known types, and prefixing
// ArgType.CustomTypePackage (if applicable).
func (a *ArgType) retype(typ string) string {
	if strings.Contains(typ, ".") {
		return typ
	}

	prefix := ""
	for strings.HasPrefix(typ, "[]") {
		typ = typ[2:]
		prefix = prefix + "[]"
	}

	if _, ok := a.KnownTypeMap[typ]; !ok {
		pkg := a.CustomTypePackage
		if pkg != "" {
			pkg = pkg + "."
		}

		return prefix + pkg + typ
	}

	return prefix + typ
}

// reniltype checks typ against known nil types (similar to retype), prefixing
// ArgType.CustomTypePackage (if applicable).
func (a *ArgType) reniltype(typ string) string {
	if strings.Contains(typ, ".") {
		return typ
	}

	if strings.HasSuffix(typ, "{}") {
		if _, ok := a.KnownTypeMap[typ[:len(typ)-2]]; ok {
			return typ
		}

		pkg := a.CustomTypePackage
		if pkg != "" {
			pkg = pkg + "."
		}

		return pkg + typ
	}

	return typ
}

// shortname generates a safe Go identifier for typ. typ is first checked
// against ArgType.ShortNameTypeMap, and if not found, then the value is
// calculated and stored in the ShortNameTypeMap for future use.
//
// A shortname is the concatentation of the lowercase of the first character in
// the words comprising the name. For example, "MyCustomName" will have have
// the shortname of "mcn".
//
// If a generated shortname conflicts with a Go reserved name, then the
// corresponding value in goReservedNames map will be used.
//
// Generated shortnames that have conflicts with any scopeConflicts member will
// have ArgType.NameConflictSuffix appended.
//
// Note: recognized types for scopeConflicts are string, []*Field,
// []*QueryParam.
func (a *ArgType) shortname(typ string, scopeConflicts ...interface{}) string {
	var v string
	var ok bool

	// check short name map
	if v, ok = a.ShortNameTypeMap[typ]; !ok {
		// calc the short name
		u := []string{}
		for _, s := range strings.Split(strings.ToLower(snaker.CamelToSnake(typ)), "_") {
			if len(s) > 0 && s != "id" {
				u = append(u, s[:1])
			}
		}
		v = strings.Join(u, "")

		// check go reserved names
		if n, ok := goReservedNames[v]; ok {
			v = n
		}

		// store back to short name map
		a.ShortNameTypeMap[typ] = v
	}

	// initial conflicts are the default imported packages from
	// xo_package.go.tpl
	conflicts := map[string]bool{
		"sql":     true,
		"driver":  true,
		"csv":     true,
		"errors":  true,
		"fmt":     true,
		"regexp":  true,
		"strings": true,
		"time":    true,
	}

	// add scopeConflicts to conflicts
	for _, c := range scopeConflicts {
		switch k := c.(type) {
		case string:
			conflicts[k] = true

		case []*Field:
			for _, f := range k {
				conflicts[f.Name] = true
			}
		case []*QueryParam:
			for _, f := range k {
				conflicts[f.Name] = true
			}

		default:
			panic("not implemented")
		}
	}

	// append suffix if conflict exists
	if _, ok := conflicts[v]; ok {
		v = v + a.NameConflictSuffix
	}

	return v
}

// colnames creates a list of the column names found in fields, excluding any
// Field with Name contained in ignoreNames.
//
// Used to present a comma separated list of column names, that can be used in
// a SELECT, or UPDATE, or other SQL clause requiring an list of identifiers
// (ie, "field_1, field_2, field_3, ...").
func (a *ArgType) colnames(fields []*Field, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + ", "
		}
		str = str + a.colname(f.Col)
		i++
	}

	return str
}

// colnamesas creates a list of the column names in fields as a `as` query,
// excluding any Field with Name contained in ignoreNames.
//
// Used to create a list of column names in a query clause (ie, "$1 AS field, $2 = field
// , ...").
func (a *ArgType) colnamesas(fields []*Field, sep string, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + sep
		}
		str = str + a.Loader.NthParam(i) + " AS " + a.colname(f.Col)
		i++
	}

	return str
}

// colnamesmulti creates a list of the column names found in fields, excluding any
// Field with Name contained in ignoreNames.
//
// Used to present a comma separated list of column names, that can be used in
// a SELECT, or UPDATE, or other SQL clause requiring an list of identifiers
// (ie, "field_1, field_2, field_3, ...").
func (a *ArgType) colnamesmulti(fields []*Field, ignoreNames []*Field) string {
	ignore := map[string]bool{}
	for _, f := range ignoreNames {
		ignore[f.Name] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + ", "
		}
		str = str + a.colname(f.Col)
		i++
	}

	return str
}

// colnamesquery creates a list of the column names in fields as a query and
// joined by sep, excluding any Field with Name contained in ignoreNames.
//
// Used to create a list of column names in a WHERE clause (ie, "field_1 = $1
// AND field_2 = $2 AND ...") or in an UPDATE clause (ie, "field = $1, field =
// $2, ...").
func (a *ArgType) colnamesquery(fields []*Field, sep string, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + sep
		}
		str = str + a.colname(f.Col) + " = " + a.Loader.NthParam(i)
		i++
	}

	return str
}

// colprefixnamesquery creates a list of the column names in fields as a query and
// joined by sep, excluding any Field with Name contained in ignoreNames.
//
// Used to create a list of column names in a WHERE clause (ie, "t1.field_1 = t2.field_1
// AND t1.field_2 = t2.field_2 AND ...") or in an UPDATE clause (ie, "t1.field = t2.field
// , ...").
func (a *ArgType) colprefixnamesquery(fields []*Field, prefixBefore string, prefixAfter string, sep string, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	if prefixBefore != "" {
		prefixBefore += "."
	}
	if prefixAfter != "" {
		prefixAfter += "."
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + sep
		}
		colname := a.colname(f.Col)
		str = str + prefixBefore + colname + " = " + prefixAfter + colname
		i++
	}

	return str
}

// colnamesquerymulti creates a list of the column names in fields as a query and
// joined by sep, excluding any Field with Name contained in the slice of fields in ignoreNames.
//
// Used to create a list of column names in a WHERE clause (ie, "field_1 = $1
// AND field_2 = $2 AND ...") or in an UPDATE clause (ie, "field = $1, field =
// $2, ...").
func (a *ArgType) colnamesquerymulti(fields []*Field, sep string, startCount int, ignoreNames []*Field) string {
	ignore := map[string]bool{}
	for _, f := range ignoreNames {
		ignore[f.Name] = true
	}

	str := ""
	i := startCount
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i > startCount {
			str = str + sep
		}
		str = str + a.colname(f.Col) + " = " + a.Loader.NthParam(i)
		i++
	}

	return str
}

// colprefixnames creates a list of the column names found in fields with the
// supplied prefix, excluding any Field with Name contained in ignoreNames.
//
// Used to present a comma separated list of column names with a prefix. Used in
// a SELECT, or UPDATE (ie, "t.field_1, t.field_2, t.field_3, ...").
func (a *ArgType) colprefixnames(fields []*Field, prefix string, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + ", "
		}
		str = str + prefix + "." + a.colname(f.Col)
		i++
	}

	return str
}

// colvals creates a list of value place holders for fields excluding any Field
// with Name contained in ignoreNames.
//
// Used to present a comma separated list of column place holders, used in a
// SELECT or UPDATE statement (ie, "$1, $2, $3 ...").
func (a *ArgType) colvals(fields []*Field, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + ", "
		}
		str = str + a.Loader.NthParam(i)
		i++
	}

	return str
}

// colvalsmulti creates a list of value place holders for fields excluding any Field
// with Name contained in ignoreNames.
//
// Used to present a comma separated list of column place holders, used in a
// SELECT or UPDATE statement (ie, "$1, $2, $3 ...").
func (a *ArgType) colvalsmulti(fields []*Field, ignoreNames []*Field) string {
	ignore := map[string]bool{}
	for _, f := range ignoreNames {
		ignore[f.Name] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + ", "
		}
		str = str + a.Loader.NthParam(i)
		i++
	}

	return str
}

// collastvals creates a value place holders for the last fields excluding any Field
// with Name contained in ignoreNames.
//
// Used to get the count of fields, and useful for specifying the last SQL
// parameter(...$n).
func (a *ArgType) collastvals(fields []*Field, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		i++
	}
	return a.Loader.NthParam(i)
}

// colnumval creates a value place holders for specified number
//
// Used to get SQL parameter(...$n)
func (a *ArgType) colnumval(n int) string {
	return a.Loader.NthParam(n - 1)
}

// mask creates a value place holders for mask
//
// Used to get SQL parameter(...$%d)
func (a *ArgType) mask() string {
	return a.Loader.Mask()
}

// fieldnames creates a list of field names from fields of the adding the
// provided prefix, and excluding any Field with Name contained in ignoreNames.
//
// Used to present a comma separated list of field names, ie in a Go statement
// (ie, "t.Field1, t.Field2, t.Field3 ...")
func (a *ArgType) fieldnames(fields []*Field, prefix string, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + ", "
		}
		str = str + prefix + "." + f.Name
		i++
	}

	return str
}

// fieldnamesmulti creates a list of field names from fields of the adding the
// provided prefix, and excluding any Field with the slice contained in ignoreNames.
//
// Used to present a comma separated list of field names, ie in a Go statement
// (ie, "t.Field1, t.Field2, t.Field3 ...")
func (a *ArgType) fieldnamesmulti(fields []*Field, prefix string, ignoreNames []*Field) string {
	ignore := map[string]bool{}
	for _, f := range ignoreNames {
		ignore[f.Name] = true
	}

	str := ""
	i := 0
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		if i != 0 {
			str = str + ", "
		}
		str = str + prefix + "." + f.Name
		i++
	}

	return str
}

// colcount returns the 1-based count of fields, excluding any Field with Name
// contained in ignoreNames.
//
// Used to get the count of fields, and useful for specifying the last SQL
// parameter.
func (a *ArgType) colcount(fields []*Field, ignoreNames ...string) int {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	i := 1
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		i++
	}
	return i
}

// goReservedNames is a map of of go reserved names to "safe" names.
var goReservedNames = map[string]string{
	"break":       "brk",
	"case":        "cs",
	"chan":        "chn",
	"const":       "cnst",
	"continue":    "cnt",
	"default":     "def",
	"defer":       "dfr",
	"else":        "els",
	"fallthrough": "flthrough",
	"for":         "fr",
	"func":        "fn",
	"go":          "goVal",
	"goto":        "gt",
	"if":          "ifVal",
	"import":      "imp",
	"interface":   "iface",
	"map":         "mp",
	"package":     "pkg",
	"range":       "rnge",
	"return":      "ret",
	"select":      "slct",
	"struct":      "strct",
	"switch":      "swtch",
	"type":        "typ",
	"var":         "vr",

	// go types
	"error":      "e",
	"bool":       "b",
	"string":     "str",
	"byte":       "byt",
	"rune":       "r",
	"uintptr":    "uptr",
	"int":        "i",
	"int8":       "i8",
	"int16":      "i16",
	"int32":      "i32",
	"int64":      "i64",
	"uint":       "u",
	"uint8":      "u8",
	"uint16":     "u16",
	"uint32":     "u32",
	"uint64":     "u64",
	"float32":    "z",
	"float64":    "f",
	"complex64":  "c",
	"complex128": "c128",
}

// goparamlist converts a list of fields into their named Go parameters,
// skipping any Field with Name contained in ignoreNames. addType will cause
// the go Type to be added after each variable name. addPrefix will cause the
// returned string to be prefixed with ", " if the generated string is not
// empty.
//
// Any field name encountered will be checked against goReservedNames, and will
// have its name substituted by its corresponding looked up value.
//
// Used to present a comma separated list of Go variable names for use with as
// either a Go func parameter list, or in a call to another Go func.
// (ie, ", a, b, c, ..." or ", a T1, b T2, c T3, ...").
func (a *ArgType) goparamlist(fields []*Field, addPrefix bool, addType bool, ignoreNames ...string) string {
	ignore := map[string]bool{}
	for _, n := range ignoreNames {
		ignore[n] = true
	}

	i := 0
	vals := []string{}
	for _, f := range fields {
		if ignore[f.Name] {
			continue
		}

		s := "v" + strconv.Itoa(i)
		if len(f.Name) > 0 {
			n := strings.Split(snaker.CamelToSnake(f.Name), "_")
			s = strings.ToLower(n[0]) + f.Name[len(n[0]):]
		}

		// check go reserved names
		if r, ok := goReservedNames[strings.ToLower(s)]; ok {
			s = r
		}

		// add the go type
		if addType {
			s += " " + a.retype(f.Type)
		}

		// add to vals
		vals = append(vals, s)

		i++
	}

	// concat generated values
	str := strings.Join(vals, ", ")
	if addPrefix && str != "" {
		return ", " + str
	}

	return str
}

// convext generates the Go conversion for f in order for it to be assignable
// to t.
//
// FIXME: this should be a better name, like "goconversion" or some such.
func (a *ArgType) convext(prefix string, f *Field, t *Field) string {
	expr := prefix + "." + f.Name
	if f.Type == t.Type {
		return expr
	}

	ft := f.Type
	if strings.HasPrefix(ft, "sql.Null") {
		expr = expr + "." + f.Type[8:]
		ft = strings.ToLower(f.Type[8:])
	}

	if t.Type != ft {
		expr = t.Type + "(" + expr + ")"
	}

	return expr
}

// schemafn takes a series of names and joins them with the schema name.
func (a *ArgType) schemafn(s string, names ...string) string {
	// escape table names
	if a.EscapeTableNames {
		for i, t := range names {
			names[i] = a.Loader.Escape(TableEsc, t)
		}
	}

	n := strings.Join(names, ".")

	if s == "" && n == "" {
		return ""
	}

	if s != "" && n != "" {
		if a.EscapeSchemaName {
			s = a.Loader.Escape(SchemaEsc, s)
		}
		s = s + "."
	}

	return s + n
}

// colname returns the ColumnName of col, optionally escaping it if
// ArgType.EscapeColumnNames is toggled.
func (a *ArgType) colname(col *models.Column) string {
	if a.EscapeColumnNames {
		return a.Loader.Escape(ColumnEsc, col.ColumnName)
	}

	return col.ColumnName
}

// parsecolname returns the ColumnName, optionally escaping it if
// ArgType.EscapeColumnNames is toggled.
func (a *ArgType) parsecolname(s string) string {
	if a.EscapeColumnNames {
		return a.Loader.Escape(ColumnEsc, s)
	}

	return s
}

// hascolumn takes a list of fields and determines if field with the specified
// column name is in the list.
func (a *ArgType) hascolumn(fields []*Field, name string) bool {
	for _, f := range fields {
		if f.Col.ColumnName == name {
			return true
		}
	}

	return false
}

// hasfield takes a list of fields and determines if field with the specified
// field name is in the list.
func (a *ArgType) hasfield(fields []*Field, name string) bool {
	for _, f := range fields {
		if f.Name == name {
			return true
		}
	}

	return false
}

// getstartcount returns a starting count for numbering columsn in queries
func (a *ArgType) getstartcount(fields []*Field, pkFields []*Field) int {
	return len(fields) - len(pkFields)
}

func (a *ArgType) plural(s string) string {
	return inflector.Pluralize(s)
}

func (a *ArgType) singular(s string) string {
	return inflector.Singularize(s)
}

var sqlToGoTypeMap = map[string]string{
	"string":              "string",
	"bool":                "bool",
	"int":                 "string",
	"int64":               "string",
	"float64":             "string",
	"time.Time":           "graphql.Time",
	"sql.NullString":      "*string",
	"[]sql.NullString":    "[]string",
	"sql.NullBool":        "*bool",
	"NullTime":            "*graphql.Time",
	"sql.NullInt64":       "*string",
	"sql.NullFloat64":     "*float64",
	"decimal.NullDecimal": "*string",
	"decimal.Decimal":     "string",
}

var sqlToGoReturnTypeMap = map[string]string{
	"string":              `""`,
	"int":                 `""`,
	"int64":               `""`,
	"float64":             `""`,
	"sql.NullString":      "nil",
	"[]sql.NullString":    "nil",
	"sql.NullInt64":       "nil",
	"sql.NullFloat64":     "nil",
	"decimal.NullDecimal": "nil",
}

var sqlNilTypeMap = map[string]string{
	"string":              "sql.NullString",
	"bool":                "sql.NullBool",
	"int":                 "sql.NullString",
	"int64":               "sql.NullString",
	"float64":             "sql.NullFloat64",
	"time.Time":           "NullTime",
	"sql.NullString":      "sql.NullString",
	"[]sql.NullString":    "[]string",
	"sql.NullBool":        "sql.NullBool",
	"NullTime":            "NullTime",
	"sql.NullInt64":       "sql.NullInt64",
	"sql.NullFloat64":     "sql.NullFloat64",
	"decimal.NullDecimal": "decimal.NullDecimal",
	"decimal.Decimal":     "decimal.NullDecimal",
}

func (a *ArgType) sqlniltype(typ string) string {
	if ret, ok := sqlNilTypeMap[typ]; ok {
		return ret
	}
	panic("in funcs.go define sqlniltype for: " + typ)
}

func (a *ArgType) sqltogotype(typ string, isPK bool) string {
	if isPK {
		return "graphql.ID"
	}
	if ret, ok := sqlToGoTypeMap[typ]; ok {
		return ret
	}
	panic("in funcs.go define sqltogotype for: " + typ)
}

func (a *ArgType) sqltogoreturntype(typ string, isPK bool) string {
	if isPK {
		panic("in funcs.go unsupported extra ac rules on pk field")
	}
	if ret, ok := sqlToGoReturnTypeMap[typ]; ok {
		return ret
	}
	panic("in funcs.go define sqltogoreturntype for: " + typ)
}

func (a *ArgType) sqltogql(typ, field string, isPK bool) string {
	if isPK && typ == "int64" {
		return "graphql.ID(strconv.FormatInt(" + field + ", 10))"
	}
	if isPK {
		return "graphql.ID(strconv.Itoa(" + field + "))"
	}
	switch typ {
	case "int":
		return "strconv.Itoa(" + field + ")"
	case "int64":
		return "strconv.FormatInt(" + field + ", 10)"
	case "float64":
		return "strconv.FormatFloat(" + field + ", 10)"
	case "string":
		return field
	case "bool":
		return field
	case "time.Time":
		return "graphql.Time{ " + field + " }"
	case "sql.NullString":
		return "PointerString(" + field + ")"
	case "[]sql.NullString":
		return field
	case "sql.NullBool":
		return "PointerBool(" + field + ")"
	case "NullTime":
		return "PointerGqlTime(" + field + ")"
	case "sql.NullInt64":
		return "PointerStringSqlInt64(" + field + ")"
	case "sql.NullFloat64":
		return "PointerFloat64SqlFloat64(" + field + ")"
	case "decimal.Decimal":
		return field + ".String()"
	case "decimal.NullDecimal":
		return "NullDecimalString(" + field + ")"
	default:
		panic("in funcs.go define sqltogql for: " + typ)
	}
}

// togqlname turns CamelCase to camelCase
func (a *ArgType) togqlname(s string) string {
	if s == "ID" {
		return "id"
	}
	return strings.ToLower(s[0:1]) + s[1:]
}

var sqlToGqlTypeMap = map[string]string{
	"string":              "String!",
	"bool":                "Boolean!",
	"int64":               "String!",
	"int":                 "String!",
	"float64":             "Float!",
	"time.Time":           "Time!",
	"sql.NullString":      "String",
	"[]sql.NullString":    "[String]",
	"sql.NullBool":        "Boolean",
	"NullTime":            "Time",
	"sql.NullInt64":       "String",
	"sql.NullFloat64":     "Float",
	"decimal.Decimal":     "String!",
	"decimal.NullDecimal": "String",
}

func (a *ArgType) sqltogqltype(typ string, isPK bool) string {
	if isPK {
		return "ID!"
	}
	if ret, ok := sqlToGqlTypeMap[typ]; ok {
		return ret
	}
	panic("in funcs.go define sqltogqltype for: " + typ)
}

func (a *ArgType) gotosql(typ, field string) string {
	switch typ {
	case "int":
		return field
	case "int64":
		return field
	case "float64":
		return field
	case "string":
		return field
	case "bool":
		return field
	case "time.Time":
		return fmt.Sprintf("%s.Time", field)
	case "sql.NullBool":
		return fmt.Sprintf("BoolPointer(%s)", field)
	case "sql.NullString":
		return fmt.Sprintf("StringPointer(%s)", field)
	case "[]sql.NullString":
		return field
	case "sql.NullFloat64":
		return fmt.Sprintf("Float64Pointer(%s)", field)
	case "NullTime":
		return fmt.Sprintf("TimeGqlPointer(%s)", field)
	case "decimal.Decimal":
		return fmt.Sprintf("decimal.NewFromString(%s)", field)
	default:
		panic("in funcs.go define gotosql for: " + typ)
	}
}

func (a *ArgType) gqlidtosql(typ, field string) string {
	return ""
}

func (a *ArgType) getforeignkey(field string, foreignkeys []*ForeignKey) *ForeignKey {
	for _, fk := range foreignkeys {
		if fk.Field.Name == field {
			return fk
		}
	}
	return nil
}

func (a *ArgType) fkname(field string) string {
	lower := strings.ToLower(field)
	if strings.HasSuffix(lower, "id") {
		return field[0 : len(field)-2]
	}
	return field
}

// e.g. RefType: User, Type: Employment, Field: UserID,    returns {User}.employments
//      RefType: User, Type: Company,    Field: CreatedBy, returns {User}.companiesCreated
func (a *ArgType) fkreversefield(fk *ForeignKey, isDup bool) string {
	newFieldName := a.plural(fk.Type.Name)
	if strings.EqualFold(fk.Field.Name, fk.RefType.Name+fk.RefField.Name) || strings.HasSuffix(strings.ToLower(fk.Field.Name), "id") {
		if isDup {
			newFieldName = fmt.Sprintf("%sBy%s", newFieldName, fk.Field.Name)
		}
		return newFieldName
	}
	if strings.HasSuffix(fk.Field.Name, "By") {
		newFieldName += fk.Field.Name[:len(fk.Field.Name)-2]
	} else {
		newFieldName += fk.Field.Name
	}
	return newFieldName
}

func (a *ArgType) islast(i, j int) bool {
	return i >= j-1
}

func (a *ArgType) isdup(name string, scope string) bool {
	dupes, ok := a.ScopeDupes[scope]
	if !ok {
		dupes = map[string]struct{}{}
		a.ScopeDupes[scope] = dupes
	}

	if _, ok := dupes[name]; ok {
		return true
	}
	dupes[name] = struct{}{}
	return false
}

// convert sql type to go pinter type in go
func (a *ArgType) sqltogopointertype(typ string, isPK bool) string {
	if isPK {
		return "*graphql.ID"
	}
	if ret, ok := sqlToGoTypeMap[typ]; ok {
		if !strings.Contains(ret, "*") {
			return fmt.Sprintf("*%s", ret)
		}
		return ret
	}
	panic("in funcs.go define sqltogotype for: " + typ)
}

// convert sql type to optional type in graphql
func (a *ArgType) sqltogqloptionaltype(typ string, isPK bool) string {
	if isPK {
		return "ID"
	}
	if ret, ok := sqlToGqlTypeMap[typ]; ok {
		if strings.Contains(ret, "!") {
			return ret[:len(ret)-1]
		}
		return ret
	}
	panic("in funcs.go define sqltogqltype for: " + typ)
}

// sql types map for filter control
var sqlTypeFilterCtlMap = map[string]string{
	"string":          "String",
	"bool":            "unsupported",
	"int64":           "Number",
	"int":             "Number",
	"float64":         "Number",
	"time.Time":       "Time",
	"sql.NullString":  "String",
	"sql.NullBool":    "unsupported",
	"NullTime":        "Time",
	"sql.NullInt64":   "Number",
	"sql.NullFloat64": "Number",
}

// flatidxfields flat indexes into one slice, except primary key
func (a *ArgType) flatidxfields(typ *Type) []*Field {
	fields := make([]*Field, 0)
	for _, index := range typ.Indexes {
		for _, field := range index.Fields {
			if !field.Col.IsPrimaryKey {
				fields = append(fields, field)
			}
		}
	}
	return fields
}

// sqlfilter sql fields control for filter
func (a *ArgType) sqlfilter(table string, field *Field, idxFields []*Field) string {
	isIndexKey := false
	for _, idxField := range idxFields {
		if idxField.Col.ColumnName == field.Col.ColumnName {
			isIndexKey = true
		}
	}
	specKey := fmt.Sprintf("%v@%v", field.Col.ColumnName, table)
	_, ok := a.ExtraFiltersMap[specKey]
	if !ok && !isIndexKey {
		return "unsupported"
	}
	if ret, ok := sqlTypeFilterCtlMap[field.Type]; ok {
		return ret
	}
	return "unsupported"
}

func (a *ArgType) existsqlfilter(typ *Type) bool {
	fields := make([]*Field, 0)
	for _, index := range typ.Indexes {
		for _, field := range index.Fields {
			if !field.Col.IsPrimaryKey {
				fields = append(fields, field)
			}
		}
	}
	if len(fields) > 0 {
		return true
	}

	for k := range a.ExtraFiltersMap {
		if strings.Contains(k, fmt.Sprintf("@%s", typ.Table.TableName)) {
			return true
		}
	}
	return false
}

func (a *ArgType) enableAC() bool {
	return a.EnableAC
}

func (a *ArgType) enableExtension() bool {
	return a.EnableExtension
}

func (a *ArgType) isACField(table string, field *Field) bool {
	key := fmt.Sprintf("%v@%v", field.Col.ColumnName, table)
	_, ok := a.ExtraACRulesMap[key]
	return ok
}

func (a *ArgType) isPrimaryIndex(index *Index) bool {
	return index.Index.IsPrimary
}

func (a *ArgType) groupIndexedResource(indexs []*Index) []string {
	m := make(map[string]struct{})
	for _, index := range indexs {
		if index.Index.IsPrimary {
			m["primary"] = struct{}{}
		} else {
			m["non-primary"] = struct{}{}
		}
	}
	var s []string
	for k := range m {
		s = append(s, k)
	}
	return s
}

// driver returns driver name
func (a *ArgType) driver() string {
	return a.LoaderType
}

// firstLetterUpper first letter to upper
func (a *ArgType) firstLetterUpper(s string) string {
	return strings.Title(s)
}

// minus is subtraction
func (a *ArgType) minus(x, y int) int {
	return x - y
}
