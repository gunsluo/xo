package cli

import (
	"database/sql"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"sort"
	"strings"

	"github.com/ghodss/yaml"
	"github.com/xo/dburl"
	"github.com/xo/xo/internal"
	"github.com/xo/xo/models"

	_ "github.com/xo/xo/loaders"
)

// Generate build the code go file by options
func Generate(arguments Arguments) error {
	var err error

	// get defaults
	args := NewDefaultInternalArgs(arguments)
	internal.Args = args

	// process args
	err = processArgs(args)
	if err != nil {
		return err
	}

	// open database
	err = openDB(args)
	if err != nil {
		return err
	}
	defer func() {
		for _, db := range args.DBS {
			db.Close()
		}
	}()

	for _, driver := range args.LoaderTypes {
		loader, ok := args.Loaders[driver]
		if !ok {
			return errors.New("not support " + driver)
		}
		// set current driver
		args.LoaderType = driver
		args.Loader = loader

		if db, ok := args.DBS[driver]; ok {
			args.DB = db
		} else {
			return errors.New("not support " + driver)
		}

		// load schema name
		args.Schema, err = loader.SchemaName(args)
		if err != nil {
			return err
		}

		// load defs into type map
		if args.QueryMode {
			err = loader.ParseQuery(args)
		} else {
			err = loader.LoadSchema(args)
		}
		if err != nil {
			return err
		}
	}

	// add schema definitions
	err = loadSchemaDefinition(args)
	if err != nil {
		return err
	}

	// add extension
	err = loadExtension(args)
	if err != nil {
		return err
	}

	// add xo
	err = args.ExecuteTemplate(internal.XOTemplate, "xo_db", "", args)
	if err != nil {
		return err
	}

	// output
	err = writeTypes(args)
	if err != nil {
		return err
	}

	return nil
}

// processArgs processs cli args.
func processArgs(args *internal.ArgType) error {
	var err error

	// get working directory
	cwd, err := os.Getwd()
	if err != nil {
		return err
	}

	// determine out path
	if args.Out == "" {
		args.Path = cwd
	} else {
		// determine what to do with Out
		fi, err := os.Stat(args.Out)
		if err == nil && fi.IsDir() {
			// out is directory
			args.Path = args.Out
		} else if err == nil && !fi.IsDir() {
			// file exists (will truncate later)
			args.Path = path.Dir(args.Out)
			args.Filename = path.Base(args.Out)

			// error if not split was set, but destination is not a directory
			if !args.SingleFile {
				return errors.New("output path is not directory")
			}
		} else if _, ok := err.(*os.PathError); ok {
			// path error (ie, file doesn't exist yet)
			args.Path = path.Dir(args.Out)
			args.Filename = path.Base(args.Out)

			// error if split was set, but dest doesn't exist
			if !args.SingleFile {
				return errors.New("output path must be a directory and already exist when not writing to a single file")
			}
		} else {
			return err
		}
	}

	// check user template path
	if args.TemplatePath != "" {
		fi, err := os.Stat(args.TemplatePath)
		if err == nil && !fi.IsDir() {
			return errors.New("template path is not directory")
		} else if err != nil {
			return errors.New("template path must exist")
		}
	}

	// fix path
	if args.Path == "." {
		args.Path = cwd
	}

	// determine package name
	if args.Package == "" {
		args.Package = path.Base(args.Path)
	}

	// determine filename if not previously set
	if args.Filename == "" {
		args.Filename = args.Package + args.Suffix
	}

	// if query mode toggled, but no query, read Stdin.
	if args.QueryMode && args.Query == "" {
		buf, err := ioutil.ReadAll(os.Stdin)
		if err != nil {
			return err
		}
		args.Query = string(buf)
	}

	// query mode parsing
	if args.Query != "" {
		args.QueryMode = true
	}

	// check that query type was specified
	if args.QueryMode && args.QueryType == "" {
		return errors.New("query type must be supplied for query parsing mode")
	}

	// query trim
	if args.QueryMode && args.QueryTrim {
		args.Query = strings.TrimSpace(args.Query)
	}

	// escape all
	if args.EscapeAll {
		args.EscapeSchemaName = true
		args.EscapeTableNames = true
		args.EscapeColumnNames = true
	}

	args.ExtraFiltersMap = make(map[string]struct{})
	args.ExtraACRulesMap = make(map[string]struct{})
	if args.ExtraRuleFile != "" {
		ruleFile := args.ExtraRuleFile
		ruleData, err := ioutil.ReadFile(ruleFile)
		if err != nil {
			return err
		}
		var extraRule internal.ExtraRule
		if err := yaml.Unmarshal(ruleData, &extraRule); err != nil {
			return err
		}
		// pre process extra filter into map with key: field@table
		for _, table := range extraRule.ExtraFilters {
			if !table.Enable {
				continue
			}
			for _, field := range table.Fields {
				key := strings.Join([]string{field, table.Name}, "@")
				args.ExtraFiltersMap[key] = struct{}{}
			}
		}
		// pre process extra rule ac rules map with key: field@table
		for _, table := range extraRule.ExtraACRules {
			if !table.Enable {
				continue
			}
			for _, field := range table.Fields {
				key := strings.Join([]string{field, table.Name}, "@")
				args.ExtraACRulesMap[key] = struct{}{}
			}
		}
	}
	// if verbose
	if args.Verbose {
		models.XOLog = func(s string, p ...interface{}) {
			fmt.Printf("SQL:\n%s\nPARAMS:\n%v\n\n", s, p)
		}
	}

	return nil
}

// openDB attempts to open a database connection.
func openDB(args *internal.ArgType) error {
	// support multiple dsn
	if len(args.DSNS) == 0 {
		return errors.New("no parameters dsn")
	}

	for _, dsn := range args.DSNS {
		// parse dsn
		u, err := dburl.Parse(dsn)
		if err != nil {
			return err
		}
		driver := u.Driver

		// save driver type
		args.LoaderTypes = append(args.LoaderTypes, driver)

		// grab loader
		loader, ok := internal.SchemaLoaders[driver]
		if !ok {
			return errors.New("unsupported database type")
		}
		args.Loaders[driver] = loader

		// open database connection
		// fix oci8 oracle driver,  should not change driver name
		if strings.HasPrefix(dsn, "oci8://") {
			odsn := dsn[7:]
			db, err := sql.Open("oci8", odsn)
			if err != nil {
				return err
			}
			args.DBS[driver] = db
		} else {
			db, err := sql.Open(driver, u.DSN)
			if err != nil {
				return err
			}
			args.DBS[driver] = db
		}
	}

	return nil
}

func loadSchemaDefinition(args *internal.ArgType) error {
	if len(args.SchemaDefinition) == 0 || len(args.LoaderTypes) == 0 {
		return nil
	}

	// use 1st element as schema definition, it should be checked later.
	drivers := args.LoaderTypes
	firstDefinition := args.SchemaDefinition[drivers[0]]

	definition := internal.SchemaDefinition{
		Tables:  firstDefinition.Tables,
		Views:   firstDefinition.Views,
		Foreign: firstDefinition.Foreign,
		Indexes: firstDefinition.Indexes,
		Drivers: drivers,
		TypeMap: args.TypeMap,
	}

	// add schema definitions
	err := args.ExecuteTemplate(internal.SchemaTemplate, "schema", "", definition)
	if err != nil {
		return err
	}

	return nil
}

func loadExtension(args *internal.ArgType) error {
	if len(args.SchemaDefinition) == 0 || len(args.LoaderTypes) == 0 {
		return nil
	}

	// use 1st element as schema definition, it should be checked later.
	driver := args.LoaderTypes[0]
	firstDefinition := args.SchemaDefinition[driver]

	// generate table extension templates
	for _, t := range firstDefinition.Tables {
		err := args.ExecuteTemplate(internal.ExtensionTemplate, t.Name, "", t)
		if err != nil {
			return err
		}
	}

	// generate view extension templates
	for _, t := range firstDefinition.Views {
		err := args.ExecuteTemplate(internal.ExtensionTemplate, t.Name, "", t)
		if err != nil {
			return err
		}
	}

	return nil
}

// NewDefaultInternalArgs returns the default arguments.
func NewDefaultInternalArgs(arguments Arguments) *internal.ArgType {
	args := &internal.ArgType{
		Verbose:                   arguments.Verbose,
		DSNS:                      arguments.DSNS,
		Schema:                    arguments.Schema,
		Out:                       arguments.Out,
		Append:                    arguments.Append,
		Suffix:                    arguments.Suffix,
		SingleFile:                arguments.SingleFile,
		Package:                   arguments.Package,
		CustomTypePackage:         arguments.CustomTypePackage,
		Int32Type:                 arguments.Int32Type,
		Uint32Type:                arguments.Uint32Type,
		IgnoreFields:              arguments.IgnoreFields,
		IgnoreTables:              arguments.IgnoreTables,
		ForeignKeyMode:            arguments.ForeignKeyMode,
		UseIndexNames:             arguments.UseIndexNames,
		UseReversedEnumConstNames: arguments.UseReversedEnumConstNames,
		QueryMode:                 arguments.QueryMode,
		Query:                     arguments.Query,
		QueryType:                 arguments.QueryType,
		QueryFunc:                 arguments.QueryFunc,
		QueryOnlyOne:              arguments.QueryOnlyOne,
		QueryTrim:                 arguments.QueryTrim,
		QueryStrip:                arguments.QueryStrip,
		QueryInterpolate:          arguments.QueryInterpolate,
		QueryTypeComment:          arguments.QueryTypeComment,
		QueryFuncComment:          arguments.QueryFuncComment,
		QueryParamDelimiter:       arguments.QueryParamDelimiter,
		QueryFields:               arguments.QueryFields,
		QueryAllowNulls:           arguments.QueryAllowNulls,
		EscapeAll:                 arguments.EscapeAll,
		EscapeSchemaName:          arguments.EscapeSchemaName,
		EscapeTableNames:          arguments.EscapeTableNames,
		EscapeColumnNames:         arguments.EscapeColumnNames,
		EnablePostgresOIDs:        arguments.EnablePostgresOIDs,
		NameConflictSuffix:        arguments.NameConflictSuffix,
		TemplatePath:              arguments.TemplatePath,
		Tags:                      arguments.Tags,
		EnableAC:                  arguments.EnableAC,
		EnableExtension:           arguments.EnableExtension,
		ExtraRuleFile:             arguments.ExtraRuleFile,

		// KnownTypeMap is the collection of known Go types.
		KnownTypeMap: map[string]bool{
			"bool":        true,
			"string":      true,
			"byte":        true,
			"rune":        true,
			"int":         true,
			"int16":       true,
			"int32":       true,
			"int64":       true,
			"uint":        true,
			"uint8":       true,
			"uint16":      true,
			"uint32":      true,
			"uint64":      true,
			"float32":     true,
			"float64":     true,
			"Slice":       true,
			"StringSlice": true,
		},

		// ShortNameTypeMap is the collection of Go style short names for types, mainly
		// used for use with declaring a func receiver on a type.
		ShortNameTypeMap: map[string]string{
			"bool":        "b",
			"string":      "s",
			"byte":        "b",
			"rune":        "r",
			"int":         "i",
			"int16":       "i",
			"int32":       "i",
			"int64":       "i",
			"uint":        "u",
			"uint8":       "u",
			"uint16":      "u",
			"uint32":      "u",
			"uint64":      "u",
			"float32":     "f",
			"float64":     "f",
			"Slice":       "s",
			"StringSlice": "ss",
		},

		DBS:              map[string]*sql.DB{},
		Loaders:          map[string]internal.Loader{},
		SchemaDefinition: map[string]internal.SchemaDefinition{},
		TypeMap:          map[string]bool{},
		ScopeDupes:       map[string]map[string]struct{}{},
	}

	if args.Suffix == "" {
		args.Suffix = ".xo.go"
	}
	if args.Int32Type == "" {
		args.Int32Type = "int"
	}
	if args.Uint32Type == "" {
		args.Uint32Type = "uint"
	}
	if args.ForeignKeyMode == nil {
		fkMode := internal.FkModeSmart
		args.ForeignKeyMode = &fkMode
	}
	if args.QueryParamDelimiter == "" {
		args.QueryParamDelimiter = "%%"
	}
	if args.NameConflictSuffix == "" {
		args.NameConflictSuffix = "Val"
	}

	return args
}

// writeTypes writes the generated definitions.
func writeTypes(args *internal.ArgType) error {
	var err error

	out := internal.TBufSlice(args.Generated)

	// sort segments
	sort.Sort(out)

	// loop, writing in order
	for _, t := range out {
		var f *os.File

		// skip when in append and type is XO
		if args.Append && t.TemplateType == internal.XOTemplate {
			continue
		}

		// check if generated template is only whitespace/empty
		bufStr := strings.TrimSpace(t.Buf.String())
		if len(bufStr) == 0 {
			continue
		}

		// get file and filename
		f, err = getFile(args, &t)
		if err != nil {
			return err
		}

		// should only be nil when type == xo
		if f == nil {
			continue
		}

		// write segment
		if !args.Append || (t.TemplateType != internal.TypeTemplate && t.TemplateType != internal.QueryTypeTemplate) {
			_, err = t.Buf.WriteTo(f)
			if err != nil {
				return err
			}
		}
	}

	// build goimports parameters, closing files
	params := []string{"-w"}
	for k, f := range files {
		params = append(params, k)

		// close
		err = f.Close()
		if err != nil {
			return err
		}
	}

	// process written files with goimports
	output, err := exec.Command("goimports", params...).CombinedOutput()
	if err != nil {
		return errors.New(string(output))
	}

	return nil
}

// files is a map of filenames to open file handles.
var files = map[string]*os.File{}

// getFile builds the filepath from the TBuf information, and retrieves the
// file from files. If the built filename is not already defined, then it calls
// the os.OpenFile with the correct parameters depending on the state of args.
func getFile(args *internal.ArgType, t *internal.TBuf) (*os.File, error) {
	var f *os.File
	var err error

	// determine filename
	filename := strings.ToLower(t.Name)
	if t.TemplateType == internal.ExtensionTemplate {
		filename += "." + internal.ExtensionTemplate.String()
	}
	if t.NeedSuffix {
		if t.Driver == "godror" {
			filename += ".oracle"
		} else {
			filename += "." + t.Driver
		}
	}
	filename += args.Suffix

	if args.SingleFile {
		filename = args.Filename
	}
	filename = path.Join(args.Path, filename)

	// lookup file
	f, ok := files[filename]
	if ok {
		return f, nil
	}

	// default open mode
	mode := os.O_RDWR | os.O_CREATE | os.O_TRUNC

	// stat file to determine if file already exists
	fi, err := os.Stat(filename)
	if err == nil && fi.IsDir() {
		return nil, errors.New("filename cannot be directory")
	} else if _, ok = err.(*os.PathError); !ok && args.Append && t.TemplateType != internal.XOTemplate {
		// file exists so append if append is set and not XO type
		mode = os.O_APPEND | os.O_WRONLY
	}

	// skip
	//if t.TemplateType == internal.XOTemplate && fi != nil {
	//	return nil, nil
	//}

	// open file
	f, err = os.OpenFile(filename, mode, 0666)
	if err != nil {
		return nil, err
	}

	// file didn't originally exist, so add package header
	if fi == nil || !args.Append {
		// add build tags
		if args.Tags != "" {
			f.WriteString(`// +build ` + args.Tags + "\n\n")
		}

		// execute
		err = args.TemplateSet().Execute(f, "xo_package.go.tpl", args)
		if err != nil {
			return nil, err
		}
	}

	// store file
	files[filename] = f

	return f, nil
}
