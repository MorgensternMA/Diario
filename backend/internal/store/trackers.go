package store

import (
	"fmt"
	"strings"
)

// Tracker kinds:
//   - check:  done / not done (value 1)
//   - count:  increments, e.g. glasses of water
//   - number: any measurement, e.g. hours slept, weight
//   - scale:  1 to 5 rating, e.g. energy level
var trackerKinds = map[string]bool{"check": true, "count": true, "number": true, "scale": true}

type Tracker struct {
	ID       int64   `json:"id"`
	Name     string  `json:"name"`
	Kind     string  `json:"kind"`
	Unit     string  `json:"unit"`
	Goal     float64 `json:"goal"`
	Color    string  `json:"color"`
	Icon     string  `json:"icon"`
	Archived bool    `json:"archived"`
	Position int     `json:"position"`
}

type TrackerEntry struct {
	TrackerID int64   `json:"tracker_id"`
	Date      string  `json:"date"`
	Value     float64 `json:"value"`
}

func (t *Tracker) validate() error {
	t.Name = strings.TrimSpace(t.Name)
	if t.Name == "" {
		return fmt.Errorf("%w: name is required", ErrInvalid)
	}
	if t.Kind == "" {
		t.Kind = "check"
	}
	if !trackerKinds[t.Kind] {
		return fmt.Errorf("%w: kind must be check, count, number or scale", ErrInvalid)
	}
	if t.Color == "" {
		t.Color = "#42A5F5"
	}
	if t.Icon == "" {
		t.Icon = "check"
	}
	return nil
}

func (s *Store) ListTrackers(includeArchived bool) ([]Tracker, error) {
	q := `SELECT id, name, kind, unit, goal, color, icon, archived, position FROM trackers`
	if !includeArchived {
		q += ` WHERE archived = 0`
	}
	q += ` ORDER BY position, id`
	rows, err := s.db.Query(q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Tracker{}
	for rows.Next() {
		var t Tracker
		if err := rows.Scan(&t.ID, &t.Name, &t.Kind, &t.Unit, &t.Goal, &t.Color, &t.Icon, &t.Archived, &t.Position); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (s *Store) CreateTracker(t Tracker) (Tracker, error) {
	if err := t.validate(); err != nil {
		return t, err
	}
	if t.Position == 0 {
		if err := s.db.QueryRow(`SELECT COALESCE(MAX(position), 0) + 1 FROM trackers`).Scan(&t.Position); err != nil {
			return t, err
		}
	}
	res, err := s.db.Exec(`INSERT INTO trackers(name, kind, unit, goal, color, icon, archived, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		t.Name, t.Kind, t.Unit, t.Goal, t.Color, t.Icon, boolInt(t.Archived), t.Position)
	if err != nil {
		return t, err
	}
	t.ID, err = res.LastInsertId()
	return t, err
}

func (s *Store) UpdateTracker(t Tracker) (Tracker, error) {
	if err := t.validate(); err != nil {
		return t, err
	}
	err := affected(s.db.Exec(`UPDATE trackers SET name = ?, kind = ?, unit = ?, goal = ?, color = ?, icon = ?, archived = ?, position = ? WHERE id = ?`,
		t.Name, t.Kind, t.Unit, t.Goal, t.Color, t.Icon, boolInt(t.Archived), t.Position, t.ID))
	return t, err
}

func (s *Store) DeleteTracker(id int64) error {
	return affected(s.db.Exec(`DELETE FROM trackers WHERE id = ?`, id))
}

// ListEntries returns entries in [from, to]. trackerID 0 means all trackers.
func (s *Store) ListEntries(trackerID int64, from, to string) ([]TrackerEntry, error) {
	if err := validRange(from, to); err != nil {
		return nil, err
	}
	if to == "" {
		to = "9999-12-31"
	}
	q := `SELECT tracker_id, date, value FROM tracker_entries WHERE date >= ? AND date <= ?`
	args := []any{from, to}
	if trackerID != 0 {
		q += ` AND tracker_id = ?`
		args = append(args, trackerID)
	}
	q += ` ORDER BY date, tracker_id`
	rows, err := s.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []TrackerEntry{}
	for rows.Next() {
		var e TrackerEntry
		if err := rows.Scan(&e.TrackerID, &e.Date, &e.Value); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) PutEntry(e TrackerEntry) (TrackerEntry, error) {
	if err := validDate(e.Date); err != nil {
		return e, err
	}
	_, err := s.db.Exec(`INSERT INTO tracker_entries(tracker_id, date, value) VALUES (?, ?, ?)
		ON CONFLICT(tracker_id, date) DO UPDATE SET value = excluded.value`, e.TrackerID, e.Date, e.Value)
	if err != nil && strings.Contains(err.Error(), "FOREIGN KEY") {
		return e, ErrNotFound
	}
	return e, err
}

func (s *Store) DeleteEntry(trackerID int64, date string) error {
	return affected(s.db.Exec(`DELETE FROM tracker_entries WHERE tracker_id = ? AND date = ?`, trackerID, date))
}
