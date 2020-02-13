package main

//go:generate ./tpl.sh
//go:generate ./gen.sh models

import (
	"fmt"
	"os"

	"github.com/alexflint/go-arg"
	"github.com/xo/xo/cli"
	"github.com/xo/xo/internal"
)

func main() {
	// circumvent all logic to just determine if xo was built with oracle
	// support
	if len(os.Args) == 2 && os.Args[1] == "--has-oracle-support" {
		var out int
		if _, ok := internal.SchemaLoaders["godror"]; ok {
			out = 1
		}

		fmt.Fprintf(os.Stdout, "%d\n", out)
		return
	}

	// parse args
	var arguments cli.Arguments
	arg.MustParse(&arguments)

	// generate the code
	err := cli.Generate(arguments)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}
