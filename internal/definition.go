package internal

// SchemaDefinition is schema definition
type SchemaDefinition struct {
	Tables  []*Type
	Views   []*Type
	Foreign []*ForeignKey
	Indexes []*Index
	Drivers []string
	TypeMap map[string]bool
}
