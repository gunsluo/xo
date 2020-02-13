// +build oracle

package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"strings"
	"time"

	_ "github.com/mattn/go-oci8"
	"github.com/sirupsen/logrus"
	"github.com/xo/dburl"
	"github.com/xo/xo/examples/booktest/oracle/models"
)

var flagVerbose = flag.Bool("v", false, "verbose")
var flagURL = flag.String("url", "oci8://booktest:booktest@localhost/booktest", "url")

func main() {
	var err error

	// set logging
	flag.Parse()
	var logger models.XOLogger
	if *flagVerbose {
		logger = logrus.New()
	}

	url, err := dburl.Parse(*flagURL)
	if err != nil {
		log.Fatal(err)
	}

	s, err := models.New(url.Driver, models.Config{Logger: logger})
	if err != nil {
		log.Fatal(err)
	}

	var driver, dsn string
	if strings.HasPrefix(*flagURL, "oci8://") {
		driver = "oci8"
		dsn = (*flagURL)[7:]
	} else {
		driver = url.Driver
		dsn = url.DSN
	}

	// open database
	db, err := sql.Open(driver, dsn)
	if err != nil {
		log.Fatal(err)
	}

	// create an author
	a := models.Author{
		Name: "Unknown Master",
	}

	// save author to database
	err = s.SaveAuthor(db, &a)
	if err != nil {
		log.Fatal(err)
	}

	// create transaction
	tx, err := db.Begin()
	if err != nil {
		log.Fatal(err)
	}

	// save first book
	now := time.Now()
	b0 := models.Book{
		AuthorID:  a.AuthorID,
		Isbn:      "1",
		Title:     "my book title",
		Year:      2016,
		Available: now,
		Tags:      sql.NullString{String: "empty", Valid: true},
	}
	err = s.SaveBook(tx, &b0)
	if err != nil {
		log.Fatal(err)
	}

	// save second book
	b1 := models.Book{
		AuthorID:  a.AuthorID,
		Isbn:      "2",
		Title:     "the second book",
		Year:      2016,
		Available: now,
		Tags:      sql.NullString{String: "cool unique", Valid: true},
	}
	err = s.SaveBook(tx, &b1)
	if err != nil {
		log.Fatal(err)
	}

	// update the title and tags
	b1.Title = "changed second title"
	b1.Tags = sql.NullString{String: "cool disastor", Valid: true}
	err = s.UpdateBook(tx, &b1)
	if err != nil {
		log.Fatal(err)
	}

	// save third book
	b2 := models.Book{
		AuthorID:  a.AuthorID,
		Isbn:      "3",
		Title:     "the third book",
		Year:      2001,
		Available: now,
		Tags:      sql.NullString{String: "cool", Valid: true},
	}
	err = s.SaveBook(tx, &b2)
	if err != nil {
		log.Fatal(err)
	}

	// save fourth book
	b3 := models.Book{
		AuthorID:  a.AuthorID,
		Isbn:      "4",
		Title:     "4th place finisher",
		Year:      2011,
		Available: now,
		Tags:      sql.NullString{String: "other", Valid: true},
	}
	err = s.SaveBook(tx, &b3)
	if err != nil {
		log.Fatal(err)
	}

	// tx commit
	err = tx.Commit()
	if err != nil {
		log.Fatal(err)
	}

	/*
		// upsert, changing ISBN and title
		b4 := models.Book{
			BookID:    b3.BookID,
			AuthorID:  a.AuthorID,
			Isbn:      "NEW ISBN",
			Title:     "never ever gonna finish, a quatrain",
			Year:      b3.Year,
			Available: b3.Available,
			Tags:      "someother",
		}
		err = b4.Upsert(db)
		if err != nil {
			log.Fatal(err)
		}
	*/

	// retrieve first book
	books0, err := s.BooksByTitleYear(db, "my book title", 2016)
	if err != nil {
		log.Fatal(err)
	}
	for _, book := range books0 {
		fmt.Printf("Book %d: %s available: %s\n", book.BookID, book.Title, book.Available.Format(time.RFC822Z))
		author, err := s.AuthorInBook(db, book)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Printf("Book %d author: %s\n", book.BookID, author.Name)
	}

	// find a book with either "cool" or "other" tag
	/*fmt.Printf("---------\nTag search results:\n")
	res, err := models.AuthorBookResultsByTags(db, "cool")
	if err != nil {
		log.Fatal(err)
	}
	for _, ab := range res {
		fmt.Printf("Book %1.0f: '%s', Author: '%s', ISBN: '%s' Tags: '%v'\n", ab.BookID, ab.BookTitle, ab.AuthorName, ab.BookIsbn, ab.BookTags)
	}*/

	// call say_hello(varchar)
	/*str, err := models.SayHello(db, "john")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("SayHello response: %s\n", str)*/

	// get book 4 and delete
	b5, err := s.BookByBookID(db, books0[0].BookID)
	if err != nil {
		log.Fatal(err)
	}
	err = s.DeleteBook(db, b5)
	if err != nil {
		log.Fatal(err)
	}
}
