package store

import (
	"database/sql"
	"fmt"
	"strings"
)

// List kinds. They only change presentation in the app (icons, quantity
// field); every list behaves the same.
var listKinds = map[string]bool{"todo": true, "groceries": true, "purchases": true, "custom": true}

type List struct {
	ID       int64  `json:"id"`
	Name     string `json:"name"`
	Kind     string `json:"kind"`
	Icon     string `json:"icon"`
	Color    string `json:"color"`
	Position int    `json:"position"`
	Pending  int    `json:"pending"`
	Total    int    `json:"total"`
}

type Item struct {
	ID       int64  `json:"id"`
	ListID   int64  `json:"list_id"`
	Text     string `json:"text"`
	Done     bool   `json:"done"`
	Quantity string `json:"quantity"`
	Note     string `json:"note"`
	DueDate  string `json:"due_date"`
	Position int    `json:"position"`
}

func (l *List) validate() error {
	l.Name = strings.TrimSpace(l.Name)
	if l.Name == "" {
		return fmt.Errorf("%w: name is required", ErrInvalid)
	}
	if l.Kind == "" {
		l.Kind = "custom"
	}
	if !listKinds[l.Kind] {
		return fmt.Errorf("%w: kind must be todo, groceries, purchases or custom", ErrInvalid)
	}
	if l.Icon == "" {
		l.Icon = "list"
	}
	if l.Color == "" {
		l.Color = "#26A69A"
	}
	return nil
}

func (s *Store) ListLists() ([]List, error) {
	rows, err := s.db.Query(`
		SELECT l.id, l.name, l.kind, l.icon, l.color, l.position,
		       COALESCE(SUM(i.done = 0), 0), COUNT(i.id)
		FROM lists l LEFT JOIN list_items i ON i.list_id = l.id
		GROUP BY l.id ORDER BY l.position, l.id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []List{}
	for rows.Next() {
		var l List
		if err := rows.Scan(&l.ID, &l.Name, &l.Kind, &l.Icon, &l.Color, &l.Position, &l.Pending, &l.Total); err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

func (s *Store) CreateList(l List) (List, error) {
	if err := l.validate(); err != nil {
		return l, err
	}
	if l.Position == 0 {
		if err := s.db.QueryRow(`SELECT COALESCE(MAX(position), 0) + 1 FROM lists`).Scan(&l.Position); err != nil {
			return l, err
		}
	}
	res, err := s.db.Exec(`INSERT INTO lists(name, kind, icon, color, position) VALUES (?, ?, ?, ?, ?)`,
		l.Name, l.Kind, l.Icon, l.Color, l.Position)
	if err != nil {
		return l, err
	}
	l.ID, err = res.LastInsertId()
	return l, err
}

func (s *Store) UpdateList(l List) (List, error) {
	if err := l.validate(); err != nil {
		return l, err
	}
	err := affected(s.db.Exec(`UPDATE lists SET name = ?, kind = ?, icon = ?, color = ?, position = ? WHERE id = ?`,
		l.Name, l.Kind, l.Icon, l.Color, l.Position, l.ID))
	return l, err
}

func (s *Store) DeleteList(id int64) error {
	return affected(s.db.Exec(`DELETE FROM lists WHERE id = ?`, id))
}

func (it *Item) validate() error {
	it.Text = strings.TrimSpace(it.Text)
	if it.Text == "" {
		return fmt.Errorf("%w: text is required", ErrInvalid)
	}
	if it.DueDate != "" {
		return validDate(it.DueDate)
	}
	return nil
}

const itemCols = `id, list_id, text, done, quantity, note, due_date, position`

func scanItems(rows *sql.Rows) ([]Item, error) {
	defer rows.Close()
	out := []Item{}
	for rows.Next() {
		var it Item
		if err := rows.Scan(&it.ID, &it.ListID, &it.Text, &it.Done, &it.Quantity, &it.Note, &it.DueDate, &it.Position); err != nil {
			return nil, err
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

// ListItems returns a list's items, pending first.
func (s *Store) ListItems(listID int64) ([]Item, error) {
	rows, err := s.db.Query(`SELECT `+itemCols+` FROM list_items WHERE list_id = ? ORDER BY done, position, id`, listID)
	if err != nil {
		return nil, err
	}
	return scanItems(rows)
}

// ItemsDue returns pending items whose due date falls in [from, to].
func (s *Store) ItemsDue(from, to string) ([]Item, error) {
	rows, err := s.db.Query(`SELECT `+itemCols+` FROM list_items
		WHERE due_date != '' AND due_date >= ? AND due_date <= ? AND done = 0
		ORDER BY due_date, id`, from, to)
	if err != nil {
		return nil, err
	}
	return scanItems(rows)
}

func (s *Store) CreateItem(it Item) (Item, error) {
	if err := it.validate(); err != nil {
		return it, err
	}
	err := s.db.QueryRow(`SELECT COALESCE(MAX(position), 0) + 1 FROM list_items WHERE list_id = ?`, it.ListID).Scan(&it.Position)
	if err != nil {
		return it, err
	}
	res, err := s.db.Exec(`INSERT INTO list_items(list_id, text, done, quantity, note, due_date, position) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		it.ListID, it.Text, boolInt(it.Done), it.Quantity, it.Note, it.DueDate, it.Position)
	if err != nil {
		if strings.Contains(err.Error(), "FOREIGN KEY") {
			return it, ErrNotFound
		}
		return it, err
	}
	it.ID, err = res.LastInsertId()
	return it, err
}

func (s *Store) GetItem(id int64) (Item, error) {
	rows, err := s.db.Query(`SELECT `+itemCols+` FROM list_items WHERE id = ?`, id)
	if err != nil {
		return Item{}, err
	}
	items, err := scanItems(rows)
	if err != nil {
		return Item{}, err
	}
	if len(items) == 0 {
		return Item{}, ErrNotFound
	}
	return items[0], nil
}

func (s *Store) UpdateItem(it Item) (Item, error) {
	if err := it.validate(); err != nil {
		return it, err
	}
	err := affected(s.db.Exec(`UPDATE list_items SET text = ?, done = ?, quantity = ?, note = ?, due_date = ?, position = ? WHERE id = ?`,
		it.Text, boolInt(it.Done), it.Quantity, it.Note, it.DueDate, it.Position, it.ID))
	if err != nil {
		return it, err
	}
	return s.GetItem(it.ID)
}

func (s *Store) DeleteItem(id int64) error {
	return affected(s.db.Exec(`DELETE FROM list_items WHERE id = ?`, id))
}

// ClearDone removes every checked item of a list and returns how many went.
func (s *Store) ClearDone(listID int64) (int64, error) {
	res, err := s.db.Exec(`DELETE FROM list_items WHERE list_id = ? AND done = 1`, listID)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
