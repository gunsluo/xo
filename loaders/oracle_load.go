// +build oracle

package loaders

import (
	_ "github.com/mattn/go-oci8"
)

func init() {
	ManualLoadOracle()
}
