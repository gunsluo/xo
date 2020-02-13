// Config is storage configuration
type Config struct {
	Logger XOLogger
}

// XODB is the common interface for database operations that can be used with
// types from schema '{{ schema .Schema }}'.
//
// This should work with database/sql.DB and database/sql.Tx.
type XODB interface {
	Exec(string, ...interface{}) (sql.Result, error)
	Query(string, ...interface{}) (*sql.Rows, error)
	QueryRow(string, ...interface{}) *sql.Row
}

// XOLogger provides the log interface used by generated queries.
type XOLogger interface {
	logrus.FieldLogger
	Log(level logrus.Level, args ...interface{})
	Logf(level logrus.Level, format string, args ...interface{})
}

func xoLog(logger XOLogger, level logrus.Level, args ...interface{}) {
	if logger != nil {
		logger.Log(level, args...)
	}
}

func xoLogf(logger XOLogger, level logrus.Level, format string, args ...interface{}) {
	if logger != nil {
		logger.Logf(level, format, args...)
	}
}

// ScannerValuer is the common interface for types that implement both the
// database/sql.Scanner and sql/driver.Valuer interfaces.
type ScannerValuer interface {
	sql.Scanner
	driver.Valuer
}

// StringSlice is a slice of strings.
type StringSlice []string

// quoteEscapeRegex is the regex to match escaped characters in a string.
var quoteEscapeRegex = regexp.MustCompile(`([^\\]([\\]{2})*)\\"`)

// Scan satisfies the sql.Scanner interface for StringSlice.
func (ss *StringSlice) Scan(src interface{}) error {
	buf, ok := src.([]byte)
	if !ok {
		return errors.New("invalid StringSlice")
	}

	// change quote escapes for csv parser
	str := quoteEscapeRegex.ReplaceAllString(string(buf), `$1""`)
	str = strings.Replace(str, `\\`, `\`, -1)

	// remove braces
	str = str[1:len(str)-1]

	// bail if only one
	if len(str) == 0 {
		*ss = StringSlice([]string{})
		return nil
	}

	// parse with csv reader
	cr := csv.NewReader(strings.NewReader(str))
	slice, err := cr.Read()
	if err != nil {
		fmt.Printf("exiting!: %v\n", err)
		return err
	}

	*ss = StringSlice(slice)

	return nil
}

// Value satisfies the driver.Valuer interface for StringSlice.
func (ss StringSlice) Value() (driver.Value, error) {
	v := make([]string, len(ss))
	for i, s := range ss {
		v[i] = `"` + strings.Replace(strings.Replace(s, `\`, `\\\`, -1), `"`, `\"`, -1) + `"`
	}
	return "{" + strings.Join(v, ",") + "}", nil
}

// Slice is a slice of ScannerValuers.
type Slice []ScannerValuer

// NullTime represents a time.Time that may be null. NullTime implements the
// sql.Scanner interface so it can be used as a scan destination, similar to
// sql.NullString.
type NullTime struct {
	Time  time.Time
	Valid bool // Valid is true if Time is not NULL
}

// Scan implements the Scanner interface.
func (nt *NullTime) Scan(value interface{}) error {
	nt.Time, nt.Valid = value.(time.Time)
	return nil
}

// Value implements the driver Valuer interface.
func (nt NullTime) Value() (driver.Value, error) {
	if !nt.Valid {
		return nil, nil
	}
	return nt.Time, nil
}

// Cursor specifies an index to sort by, the direction of the sort, an offset, and a limit.
type Cursor struct {
	Offset *int32
	Limit  *int32
	OrderBy  *string
	Desc   *bool
	Dead   *bool
	After  *graphql.ID
	First  *int32
	Before *graphql.ID
	Last   *int32
}

var (
	defaultOffset 	int32  = 0
	defaultLimit  	int32  = 50
	defaultOrderBy  string = "id"
	defaultDesc   	bool   = false
	defaultDead   	bool   = false
)

// DefaultCursor will get the 50 first non-deleted IDs from a table.
var DefaultCursor = Cursor{
	Offset: &defaultOffset,
	Limit:  &defaultLimit,
	OrderBy:  &defaultOrderBy,
	Desc:   &defaultDesc,
	Dead:   &defaultDead,
}

// sqlConjunctionMap supported conjunction, related to graphql enum: FilterConjunction
var sqlConjunctionMap = map[string]struct{}{
	"AND":{},
	"OR":{},
}

// filterPair item of filter
type filterPair struct{
	fieldName string
	option string
	value interface{}
}

// filterArguments filter arguments
type filterArguments struct{
	filterPairs []*filterPair
	conjunction string
	conjCnt int
}

// updateArguments additional parameters when updating method
type updateArguments struct {
	Deletions *[]string
}

// isDeletionFields return a bool value whether the field is set to null
func isDeletionFields(deletionFields *[]string, field string) bool {
	if deletionFields == nil {
		return false
	}

	for _, deletionField := range *deletionFields {
		if field == deletionField {
			return true
		}
	}

	return false
}
