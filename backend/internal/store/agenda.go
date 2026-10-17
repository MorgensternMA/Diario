package store

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
)

// Category groups agenda events (exams, medical appointments, social...).
type Category struct {
	ID    int64  `json:"id"`
	Name  string `json:"name"`
	Color string `json:"color"`
	Icon  string `json:"icon"`
}

// Event is a dated agenda entry, optionally with a time ("HH:MM").
type Event struct {
	ID         int64  `json:"id"`
	CategoryID *int64 `json:"category_id"`
	Title      string `json:"title"`
	Date       string `json:"date"`
	Time       string `json:"time"`
	Notes      string `json:"notes"`
	Done       bool   `json:"done"`
}

func (c *Category) validate() error {
	c.Name = strings.TrimSpace(c.Name)
	if c.Name == "" {
		return fmt.Errorf("%w: name is required", ErrInvalid)
	}
	if c.Color == "" {
		c.Color = "#7E57C2"
	}
	if c.Icon == "" {
		c.Icon = "event"
	}
	return nil
}

func (s *Store) ListCategories() ([]Category, error) {
	rows, err := s.db.Query(`SELECT id, name, color, icon FROM categories ORDER BY name COLLATE NOCASE`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Category{}
	for rows.Next() {
		var c Category
		if err := rows.Scan(&c.ID, &c.Name, &c.Color, &c.Icon); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) CreateCategory(c Category) (Category, error) {
	if err := c.validate(); err != nil {
		return c, err
	}
	res, err := s.db.Exec(`INSERT INTO categories(name, color, icon) VALUES (?, ?, ?)`, c.Name, c.Color, c.Icon)
	if err != nil {
		return c, err
	}
	c.ID, err = res.LastInsertId()
	return c, err
}

func (s *Store) UpdateCategory(c Category) (Category, error) {
	if err := c.validate(); err != nil {
		return c, err
	}
	err := affected(s.db.Exec(`UPDATE categories SET name = ?, color = ?, icon = ? WHERE id = ?`, c.Name, c.Color, c.Icon, c.ID))
	return c, err
}

func (s *Store) DeleteCategory(id int64) error {
	return affected(s.db.Exec(`DELETE FROM categories WHERE id = ?`, id))
}

func (e *Event) validate() error {
	e.Title = strings.TrimSpace(e.Title)
	if e.Title == "" {
		return fmt.Errorf("%w: title is required", ErrInvalid)
	}
	if err := validDate(e.Date); err != nil {
		return err
	}
	if e.Time != "" {
		var h, m int
		if n, _ := fmt.Sscanf(e.Time, "%d:%d", &h, &m); n != 2 || h < 0 || h > 23 || m < 0 || m > 59 || len(e.Time) != 5 {
			return fmt.Errorf("%w: time must be HH:MM", ErrInvalid)
		}
	}
	return nil
}

// EventFilter narrows ListEvents. Empty fields are ignored.
type EventFilter struct {
	From, To   string
	CategoryID int64
	Pending    bool
}

const eventCols = `id, category_id, title, date, time, notes, done`

func scanEvent(sc interface{ Scan(...any) error }) (Event, error) {
	var e Event
	var cat sql.NullInt64
	err := sc.Scan(&e.ID, &cat, &e.Title, &e.Date, &e.Time, &e.Notes, &e.Done)
	if cat.Valid {
		e.CategoryID = &cat.Int64
	}
	return e, err
}

func (s *Store) ListEvents(f EventFilter) ([]Event, error) {
	if err := validRange(f.From, f.To); err != nil {
		return nil, err
	}
	q := `SELECT ` + eventCols + ` FROM events WHERE 1=1`
	var args []any
	if f.From != "" {
		q += ` AND date >= ?`
		args = append(args, f.From)
	}
	if f.To != "" {
		q += ` AND date <= ?`
		args = append(args, f.To)
	}
	if f.CategoryID != 0 {
		q += ` AND category_id = ?`
		args = append(args, f.CategoryID)
	}
	if f.Pending {
		q += ` AND done = 0`
	}
	q += ` ORDER BY date, time = '', time, id`

	rows, err := s.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Event{}
	for rows.Next() {
		e, err := scanEvent(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) GetEvent(id int64) (Event, error) {
	e, err := scanEvent(s.db.QueryRow(`SELECT `+eventCols+` FROM events WHERE id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return e, ErrNotFound
	}
	return e, err
}

func (s *Store) CreateEvent(e Event) (Event, error) {
	if err := e.validate(); err != nil {
		return e, err
	}
	res, err := s.db.Exec(`INSERT INTO events(category_id, title, date, time, notes, done) VALUES (?, ?, ?, ?, ?, ?)`,
		e.CategoryID, e.Title, e.Date, e.Time, e.Notes, boolInt(e.Done))
	if err != nil {
		return e, err
	}
	e.ID, err = res.LastInsertId()
	return e, err
}

func (s *Store) UpdateEvent(e Event) (Event, error) {
	if err := e.validate(); err != nil {
		return e, err
	}
	err := affected(s.db.Exec(`UPDATE events SET category_id = ?, title = ?, date = ?, time = ?, notes = ?, done = ? WHERE id = ?`,
		e.CategoryID, e.Title, e.Date, e.Time, e.Notes, boolInt(e.Done), e.ID))
	return e, err
}

func (s *Store) DeleteEvent(id int64) error {
	return affected(s.db.Exec(`DELETE FROM events WHERE id = ?`, id))
}
