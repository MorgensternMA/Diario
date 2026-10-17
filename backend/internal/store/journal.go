package store

import (
	"database/sql"
	"errors"
	"fmt"
)

// JournalEntry is the daily "how do I feel" record. Mood goes from 1 (very
// bad) to 5 (great); 0 means not set.
type JournalEntry struct {
	Date     string   `json:"date"`
	Mood     int      `json:"mood"`
	Feelings []string `json:"feelings"`
	Note     string   `json:"note"`
}

func (j *JournalEntry) validate() error {
	if err := validDate(j.Date); err != nil {
		return err
	}
	if j.Mood < 0 || j.Mood > 5 {
		return fmt.Errorf("%w: mood must be between 0 and 5", ErrInvalid)
	}
	if j.Feelings == nil {
		j.Feelings = []string{}
	}
	return nil
}

func (s *Store) GetJournal(date string) (JournalEntry, error) {
	j := JournalEntry{Date: date}
	var feelings string
	err := s.db.QueryRow(`SELECT mood, feelings, note FROM journal WHERE date = ?`, date).Scan(&j.Mood, &feelings, &j.Note)
	if errors.Is(err, sql.ErrNoRows) {
		return j, ErrNotFound
	}
	j.Feelings = decodeTags(feelings)
	return j, err
}

func (s *Store) ListJournal(from, to string) ([]JournalEntry, error) {
	if err := validRange(from, to); err != nil {
		return nil, err
	}
	if to == "" {
		to = "9999-12-31"
	}
	rows, err := s.db.Query(`SELECT date, mood, feelings, note FROM journal WHERE date >= ? AND date <= ? ORDER BY date DESC`, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []JournalEntry{}
	for rows.Next() {
		var j JournalEntry
		var feelings string
		if err := rows.Scan(&j.Date, &j.Mood, &feelings, &j.Note); err != nil {
			return nil, err
		}
		j.Feelings = decodeTags(feelings)
		out = append(out, j)
	}
	return out, rows.Err()
}

// PutJournal creates or replaces the entry for j.Date.
func (s *Store) PutJournal(j JournalEntry) (JournalEntry, error) {
	if err := j.validate(); err != nil {
		return j, err
	}
	_, err := s.db.Exec(`INSERT INTO journal(date, mood, feelings, note) VALUES (?, ?, ?, ?)
		ON CONFLICT(date) DO UPDATE SET mood = excluded.mood, feelings = excluded.feelings, note = excluded.note`,
		j.Date, j.Mood, encodeTags(j.Feelings), j.Note)
	return j, err
}

func (s *Store) DeleteJournal(date string) error {
	return affected(s.db.Exec(`DELETE FROM journal WHERE date = ?`, date))
}
