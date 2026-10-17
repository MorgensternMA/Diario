// Package store holds the SQLite persistence layer and domain logic for Diario.
package store

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

// DateLayout is the canonical format for every date stored and exchanged.
const DateLayout = "2006-01-02"

var (
	ErrNotFound = errors.New("not found")
	ErrInvalid  = errors.New("invalid input")
)

type Store struct {
	db *sql.DB
}

// Open opens (or creates) the database at path, applies the schema and seeds
// default content on first run.
func Open(path string) (*Store, error) {
	dsn := "file:" + path + "?_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	// SQLite allows a single writer; one connection keeps things simple and
	// avoids SQLITE_BUSY. Callers must close rows before issuing new queries.
	db.SetMaxOpenConns(1)

	s := &Store{db: db}
	if err := s.migrate(); err != nil {
		db.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}
	if err := s.seed(); err != nil {
		db.Close()
		return nil, fmt.Errorf("seed: %w", err)
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

const schema = `
CREATE TABLE IF NOT EXISTS meta (
	key   TEXT PRIMARY KEY,
	value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
	id    INTEGER PRIMARY KEY,
	name  TEXT NOT NULL,
	color TEXT NOT NULL DEFAULT '#7E57C2',
	icon  TEXT NOT NULL DEFAULT 'event'
);

CREATE TABLE IF NOT EXISTS events (
	id          INTEGER PRIMARY KEY,
	category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
	title       TEXT NOT NULL,
	date        TEXT NOT NULL,
	time        TEXT NOT NULL DEFAULT '',
	notes       TEXT NOT NULL DEFAULT '',
	done        INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS events_date ON events(date);

CREATE TABLE IF NOT EXISTS lists (
	id       INTEGER PRIMARY KEY,
	name     TEXT NOT NULL,
	kind     TEXT NOT NULL DEFAULT 'custom',
	icon     TEXT NOT NULL DEFAULT 'list',
	color    TEXT NOT NULL DEFAULT '#26A69A',
	position INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS list_items (
	id       INTEGER PRIMARY KEY,
	list_id  INTEGER NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
	text     TEXT NOT NULL,
	done     INTEGER NOT NULL DEFAULT 0,
	quantity TEXT NOT NULL DEFAULT '',
	note     TEXT NOT NULL DEFAULT '',
	due_date TEXT NOT NULL DEFAULT '',
	position INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS list_items_list ON list_items(list_id);
CREATE INDEX IF NOT EXISTS list_items_due ON list_items(due_date);

CREATE TABLE IF NOT EXISTS journal (
	date     TEXT PRIMARY KEY,
	mood     INTEGER NOT NULL DEFAULT 0,
	feelings TEXT NOT NULL DEFAULT '[]',
	note     TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS period_days (
	date     TEXT PRIMARY KEY,
	flow     INTEGER NOT NULL,
	symptoms TEXT NOT NULL DEFAULT '[]',
	note     TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS trackers (
	id       INTEGER PRIMARY KEY,
	name     TEXT NOT NULL,
	kind     TEXT NOT NULL DEFAULT 'check',
	unit     TEXT NOT NULL DEFAULT '',
	goal     REAL NOT NULL DEFAULT 0,
	color    TEXT NOT NULL DEFAULT '#42A5F5',
	icon     TEXT NOT NULL DEFAULT 'check',
	archived INTEGER NOT NULL DEFAULT 0,
	position INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS tracker_entries (
	tracker_id INTEGER NOT NULL REFERENCES trackers(id) ON DELETE CASCADE,
	date       TEXT NOT NULL,
	value      REAL NOT NULL,
	PRIMARY KEY (tracker_id, date)
);
`

func (s *Store) migrate() error {
	_, err := s.db.Exec(schema)
	return err
}

// seed inserts starter categories, lists and trackers exactly once, so that
// deleting them later doesn't bring them back.
func (s *Store) seed() error {
	var done string
	err := s.db.QueryRow(`SELECT value FROM meta WHERE key = 'seeded'`).Scan(&done)
	if err == nil {
		return nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return err
	}

	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmts := []struct {
		q    string
		args []any
	}{
		{`INSERT INTO categories(name, color, icon) VALUES (?, ?, ?)`, []any{"Exámenes", "#EF5350", "school"}},
		{`INSERT INTO categories(name, color, icon) VALUES (?, ?, ?)`, []any{"Turnos médicos", "#26A69A", "medical"}},
		{`INSERT INTO categories(name, color, icon) VALUES (?, ?, ?)`, []any{"Social", "#FFA726", "people"}},
		{`INSERT INTO categories(name, color, icon) VALUES (?, ?, ?)`, []any{"Trabajo", "#5C6BC0", "work"}},
		{`INSERT INTO lists(name, kind, icon, color, position) VALUES (?, ?, ?, ?, ?)`, []any{"Pendientes", "todo", "check", "#7E57C2", 1}},
		{`INSERT INTO lists(name, kind, icon, color, position) VALUES (?, ?, ?, ?, ?)`, []any{"Supermercado", "groceries", "cart", "#66BB6A", 2}},
		{`INSERT INTO lists(name, kind, icon, color, position) VALUES (?, ?, ?, ?, ?)`, []any{"Compras importantes", "purchases", "bag", "#FFA726", 3}},
		{`INSERT INTO trackers(name, kind, unit, goal, color, icon, position) VALUES (?, ?, ?, ?, ?, ?, ?)`, []any{"Agua", "count", "vasos", 8, "#42A5F5", "water", 1}},
		{`INSERT INTO trackers(name, kind, unit, goal, color, icon, position) VALUES (?, ?, ?, ?, ?, ?, ?)`, []any{"Ejercicio", "check", "", 0, "#66BB6A", "fitness", 2}},
		{`INSERT INTO trackers(name, kind, unit, goal, color, icon, position) VALUES (?, ?, ?, ?, ?, ?, ?)`, []any{"Sueño", "number", "horas", 8, "#7E57C2", "sleep", 3}},
		{`INSERT INTO meta(key, value) VALUES ('seeded', '1')`, nil},
	}
	for _, st := range stmts {
		if _, err := tx.Exec(st.q, st.args...); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// ParseDate validates a YYYY-MM-DD string.
func ParseDate(s string) (time.Time, error) {
	t, err := time.Parse(DateLayout, s)
	if err != nil {
		return time.Time{}, fmt.Errorf("%w: date %q must be YYYY-MM-DD", ErrInvalid, s)
	}
	return t, nil
}

func validDate(s string) error {
	_, err := ParseDate(s)
	return err
}

// validRange checks optional from/to bounds; empty strings mean unbounded.
func validRange(from, to string) error {
	if from != "" {
		if err := validDate(from); err != nil {
			return err
		}
	}
	if to != "" {
		if err := validDate(to); err != nil {
			return err
		}
	}
	return nil
}

func encodeTags(tags []string) string {
	if tags == nil {
		tags = []string{}
	}
	b, _ := json.Marshal(tags)
	return string(b)
}

func decodeTags(s string) []string {
	tags := []string{}
	_ = json.Unmarshal([]byte(s), &tags)
	return tags
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// affected turns a zero-rows result into ErrNotFound.
func affected(res sql.Result, err error) error {
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}
