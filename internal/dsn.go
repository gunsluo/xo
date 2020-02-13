package internal

import (
	"strings"
)

// DSNS represents the multiple dsn.
type DSNS []string

// UnmarshalText unmarshals FkMode from text.
func (ds *DSNS) UnmarshalText(text []byte) error {
	var ns DSNS
	ns = strings.Split(string(text), ",")
	*ds = ns
	return nil
}

// String satisfies the Stringer interface.
func (ds DSNS) String() string {
	return strings.Join(ds, ",")
}
