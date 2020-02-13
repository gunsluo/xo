package loaders

import (
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/xo/xo/internal"
	"github.com/xo/xo/models"
)

// ManualLoadOracle manual load oracle schema
func ManualLoadOracle() {
	if _, ok := internal.SchemaLoaders["godror"]; !ok {
		internal.SchemaLoaders["godror"] = internal.TypeLoader{
			ParamN:         func(i int) string { return fmt.Sprintf(":%d", i+1) },
			MaskFunc:       func() string { return ":%d" },
			ProcessRelkind: OrRelkind,
			Schema:         OrSchema,
			ParseType:      OrParseType,
			//EnumList:        models.OrEnums,
			//EnumValueList:   OrEnumValues,
			//ProcList:      models.OrProcs,
			//ProcParamList: models.OrProcParams,
			TableList:       models.OrTables,
			ColumnList:      OrTableColumns,
			ForeignKeyList:  OrTableForeignKeys,
			IndexList:       OrTableIndexes,
			IndexColumnList: OrIndexColumns,
			QueryColumnList: OrQueryColumns,
		}
	}
}

// OrRelkind returns the oracle string representation for RelType.
func OrRelkind(relType internal.RelType) string {
	var s string
	switch relType {
	case internal.Table:
		s = "TABLE"
	case internal.View:
		s = "VIEW"
	default:
		panic("unsupported RelType")
	}
	return s
}

// OrSchema retrieves the name of the current schema.
func OrSchema(args *internal.ArgType) (string, error) {
	var err error

	// sql query
	const sqlstr = `SELECT UPPER(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')) FROM dual`

	var schema string

	// run query
	models.XOLog(sqlstr)
	err = args.DB.QueryRow(sqlstr).Scan(&schema)
	if err != nil {
		return "", err
	}

	return schema, nil
}

// OrLenRE is a regexp that matches lengths.
var OrLenRE = regexp.MustCompile(`\([0-9]+\)`)

// OrParseType parse a oracle type into a Go type based on the column
// definition.
func OrParseType(args *internal.ArgType, dt string, nullable bool) (int, string, string) {
	nilVal := "nil"

	dt = strings.ToLower(dt)

	// extract precision
	dt, precision, scale := args.ParsePrecision(dt)

	var typ string
	// strip remaining length (on things like timestamp)
	switch OrLenRE.ReplaceAllString(dt, "") {
	case "char", "nchar", "varchar", "varchar2", "nvarchar2",
		"long",
		"clob", "nclob",
		"rowid":
		nilVal = `""`
		typ = "string"
		if nullable {
			nilVal = "sql.NullString{}"
			typ = "sql.NullString"
		}
	case "shortint":
		nilVal = "0"
		typ = "int16"
		if nullable {
			nilVal = "sql.NullInt64{}"
			typ = "sql.NullInt64"
		}
	case "integer":
		nilVal = "0"
		typ = args.Int32Type
		if nullable {
			nilVal = "sql.NullInt64{}"
			typ = "sql.NullInt64"
		}
	case "longinteger":
		nilVal = "0"
		typ = "int64"
		if nullable {
			nilVal = "sql.NullInt64{}"
			typ = "sql.NullInt64"
		}

	case "float", "shortdecimal":
		nilVal = "0.0"
		typ = "float32"
		if nullable {
			nilVal = "sql.NullFloat64{}"
			typ = "sql.NullFloat64"
		}

	case "number", "decimal":
		nilVal = "0.0"
		if 0 < precision && precision < 18 && scale > 0 {
			typ = "float64"
			if nullable {
				nilVal = "sql.NullFloat64{}"
				typ = "sql.NullFloat64"
			}
		} else if 0 < precision && precision <= 19 && scale == 0 {
			typ = "int64"
			if nullable {
				nilVal = "sql.NullInt64{}"
				typ = "sql.NullInt64"
			}
		} else {
			nilVal = "0"
			typ = args.Int32Type
			if nullable {
				nilVal = "sql.NullInt64{}"
				typ = "sql.NullInt64"
			}
		}

	case "blob", "long raw", "raw":
		typ = "[]byte"

	case "date", "timestamp", "timestamp with time zone":
		typ = "time.Time"
		nilVal = "time.Time{}"
		if nullable {
			nilVal = "NullTime{}"
			typ = "NullTime"
		}

	default:
		// bail
		fmt.Fprintf(os.Stderr, "error: unknown type %q\n", dt)
		os.Exit(1)
	}

	// special case for bool
	if typ == "int" && precision == 1 {
		nilVal = "false"
		typ = "bool"
		if nullable {
			nilVal = "sql.NullBool{}"
			typ = "sql.NullBool"
		}
	}

	return precision, nilVal, typ
}

// OrQueryColumns parses the query and generates a type for it.
func OrQueryColumns(args *internal.ArgType, inspect []string) ([]*models.Column, error) {
	var err error

	// create temporary view xoid
	xoid := "XO$" + internal.GenRandomID()
	viewq := `CREATE GLOBAL TEMPORARY TABLE ` + xoid + ` ` +
		`ON COMMIT PRESERVE ROWS ` +
		`AS ` + strings.Join(inspect, "\n")
	models.XOLog(viewq)
	_, err = args.DB.Exec(viewq)
	if err != nil {
		return nil, err
	}

	// load columns
	cols, err := OrTableColumns(args.DB, args.Schema, xoid)

	// drop inspect view
	dropq := `DROP TABLE ` + xoid
	models.XOLog(dropq)
	_, _ = args.DB.Exec(dropq)

	// load column information
	return cols, err
}

// OrTableIndexes runs a custom query, returning results as Index.
func OrTableIndexes(db models.XODB, schema string, table string) ([]*models.Index, error) {
	var err error

	// sql query
	const sqlstr = `SELECT ` +
		`LOWER(i.index_name) AS index_name, ` +
		`CASE WHEN i.uniqueness = 'UNIQUE' THEN '1' ELSE '0' END AS is_unique, ` +
		`CASE WHEN c.constraint_type = 'P' THEN '1' ELSE '0' END AS is_primary ` +
		`FROM user_indexes i ` +
		`LEFT JOIN user_constraints c on i.INDEX_NAME = c.constraint_name ` +
		`WHERE i.TABLE_OWNER = UPPER(:1) AND i.TABLE_NAME = :2`

	// run query
	models.XOLog(sqlstr, schema, table)
	q, err := db.Query(sqlstr, schema, table)
	if err != nil {
		return nil, err
	}
	defer q.Close()

	// load results
	res := []*models.Index{}
	for q.Next() {
		i := models.Index{}

		// scan
		err = q.Scan(&i.IndexName, &i.IsUnique, &i.IsPrimary)
		if err != nil {
			return nil, err
		}

		res = append(res, &i)
	}

	return res, nil
}

// OrTableColumns runs a custom query, returning results as Column.
func OrTableColumns(db models.XODB, schema string, table string) ([]*models.Column, error) {
	var err error

	// sql query
	const sqlstr = `SELECT ` +
		`c.column_id AS field_ordinal, ` +
		`LOWER(c.column_name) AS column_name, ` +
		`LOWER(CASE c.data_type ` +
		`WHEN 'CHAR' THEN 'CHAR('||c.data_length||')' ` +
		`WHEN 'VARCHAR2' THEN 'VARCHAR2('||data_length||')' ` +
		`WHEN 'NUMBER' THEN ` +
		`(CASE WHEN c.data_precision IS NULL AND c.data_scale IS NULL THEN 'NUMBER' ` +
		`ELSE 'NUMBER('||NVL(c.data_precision, 38)||','||NVL(c.data_scale, 0)||')' END) ` +
		`ELSE c.data_type END) AS data_type, ` +
		`CASE WHEN c.nullable = 'N' THEN '1' ELSE '0' END AS not_null, ` +
		`COALESCE((SELECT CASE WHEN r.constraint_type = 'P' THEN '1' ELSE '0' END ` +
		`FROM all_cons_columns l, all_constraints r ` +
		`WHERE r.constraint_type = 'P' AND r.owner = c.owner AND r.table_name = c.table_name AND r.constraint_name = l.constraint_name ` +
		`AND l.owner = c.owner AND l.table_name = c.table_name AND l.column_name = c.column_name), '0') AS is_primary_key ` +
		`FROM all_tab_columns c ` +
		`WHERE c.owner = UPPER(:1) AND c.table_name = :2 ` +
		`ORDER BY c.column_id`

	// run query
	models.XOLog(sqlstr, schema, table)
	q, err := db.Query(sqlstr, schema, table)
	if err != nil {
		return nil, err
	}
	defer q.Close()

	// load results
	res := []*models.Column{}
	for q.Next() {
		c := models.Column{}

		// scan
		err = q.Scan(&c.FieldOrdinal, &c.ColumnName, &c.DataType, &c.NotNull, &c.IsPrimaryKey)
		if err != nil {
			return nil, err
		}

		res = append(res, &c)
	}

	return res, nil
}

// OrIndexColumns runs a custom query, returning results as IndexColumn.
func OrIndexColumns(db models.XODB, schema string, table string, index string) ([]*models.IndexColumn, error) {
	var err error

	// sql query
	const sqlstr = `SELECT ` +
		`column_position AS seq_no, ` +
		`LOWER(column_name) AS column_name ` +
		`FROM all_ind_columns ` +
		`WHERE index_owner = UPPER(:1) AND table_name = :2 AND index_name = UPPER(:3) ` +
		`ORDER BY column_position`

	// run query
	models.XOLog(sqlstr, schema, table, index)
	q, err := db.Query(sqlstr, schema, table, index)
	if err != nil {
		return nil, err
	}
	defer q.Close()

	// load results
	res := []*models.IndexColumn{}
	for q.Next() {
		ic := models.IndexColumn{}

		// scan
		err = q.Scan(&ic.SeqNo, &ic.ColumnName)
		if err != nil {
			return nil, err
		}

		res = append(res, &ic)
	}

	return res, nil
}

// OrTableForeignKeys runs a custom query, returning results as ForeignKey.
func OrTableForeignKeys(db models.XODB, schema string, table string) ([]*models.ForeignKey, error) {
	var err error

	// sql query
	// ref_column_name
	const sqlstr = `SELECT ` +
		`LOWER(a.constraint_name) AS foreign_key_name, ` +
		`LOWER(a.column_name) AS column_name, ` +
		`LOWER(r.constraint_name) AS ref_index_name, ` +
		`LOWER(r.table_name) AS ref_table_name, ` +
		`LOWER(i.column_name) AS ref_column_name ` +
		`FROM all_cons_columns a ` +
		`JOIN all_constraints c ON a.owner = c.owner AND a.constraint_name = c.constraint_name ` +
		`JOIN all_constraints r ON c.r_owner = r.owner AND c.r_constraint_name = r.constraint_name ` +
		`JOIN all_cons_columns i ON c.r_owner = r.owner AND r.index_name = i.constraint_name ` +
		`WHERE c.constraint_type = 'R' AND a.owner = UPPER(:1) AND a.table_name = :2`

	// run query
	models.XOLog(sqlstr, schema, table)
	q, err := db.Query(sqlstr, schema, table)
	if err != nil {
		return nil, err
	}
	defer q.Close()

	// load results
	res := []*models.ForeignKey{}
	for q.Next() {
		fk := models.ForeignKey{}

		// scan
		err = q.Scan(&fk.ForeignKeyName, &fk.ColumnName, &fk.RefIndexName, &fk.RefTableName, &fk.RefColumnName)
		if err != nil {
			return nil, err
		}

		res = append(res, &fk)
	}

	return res, nil
}
