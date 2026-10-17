package api

import (
	"net/http"
	"strconv"

	"github.com/MorgensternMA/diario/backend/internal/store"
)

// --- Day & calendar ---

func (s *Server) getDay(w http.ResponseWriter, r *http.Request) {
	date, ok := pathDate(w, r)
	if !ok {
		return
	}
	d, err := s.store.Day(date)
	respond(w, http.StatusOK, d, err)
}

func (s *Server) getCalendar(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	days, err := s.store.Calendar(q.Get("from"), q.Get("to"), s.today())
	respond(w, http.StatusOK, days, err)
}

// --- Categories ---

func (s *Server) listCategories(w http.ResponseWriter, r *http.Request) {
	cats, err := s.store.ListCategories()
	respond(w, http.StatusOK, cats, err)
}

func (s *Server) createCategory(w http.ResponseWriter, r *http.Request) {
	var c store.Category
	if !decode(w, r, &c) {
		return
	}
	c, err := s.store.CreateCategory(c)
	respond(w, http.StatusCreated, c, err)
}

func (s *Server) updateCategory(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var c store.Category
	if !decode(w, r, &c) {
		return
	}
	c.ID = id
	c, err := s.store.UpdateCategory(c)
	respond(w, http.StatusOK, c, err)
}

func (s *Server) deleteCategory(w http.ResponseWriter, r *http.Request) {
	if id, ok := pathID(w, r); ok {
		noContent(w, s.store.DeleteCategory(id))
	}
}

// --- Events ---

func (s *Server) listEvents(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	f := store.EventFilter{From: q.Get("from"), To: q.Get("to"), Pending: q.Get("pending") == "1"}
	if c := q.Get("category_id"); c != "" {
		id, err := strconv.ParseInt(c, 10, 64)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid category_id")
			return
		}
		f.CategoryID = id
	}
	events, err := s.store.ListEvents(f)
	respond(w, http.StatusOK, events, err)
}

func (s *Server) createEvent(w http.ResponseWriter, r *http.Request) {
	var e store.Event
	if !decode(w, r, &e) {
		return
	}
	e, err := s.store.CreateEvent(e)
	respond(w, http.StatusCreated, e, err)
}

func (s *Server) updateEvent(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var e store.Event
	if !decode(w, r, &e) {
		return
	}
	e.ID = id
	e, err := s.store.UpdateEvent(e)
	respond(w, http.StatusOK, e, err)
}

func (s *Server) deleteEvent(w http.ResponseWriter, r *http.Request) {
	if id, ok := pathID(w, r); ok {
		noContent(w, s.store.DeleteEvent(id))
	}
}

// --- Lists & items ---

func (s *Server) listLists(w http.ResponseWriter, r *http.Request) {
	lists, err := s.store.ListLists()
	respond(w, http.StatusOK, lists, err)
}

func (s *Server) createList(w http.ResponseWriter, r *http.Request) {
	var l store.List
	if !decode(w, r, &l) {
		return
	}
	l, err := s.store.CreateList(l)
	respond(w, http.StatusCreated, l, err)
}

func (s *Server) updateList(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var l store.List
	if !decode(w, r, &l) {
		return
	}
	l.ID = id
	l, err := s.store.UpdateList(l)
	respond(w, http.StatusOK, l, err)
}

func (s *Server) deleteList(w http.ResponseWriter, r *http.Request) {
	if id, ok := pathID(w, r); ok {
		noContent(w, s.store.DeleteList(id))
	}
}

func (s *Server) listItems(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	items, err := s.store.ListItems(id)
	respond(w, http.StatusOK, items, err)
}

func (s *Server) createItem(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var it store.Item
	if !decode(w, r, &it) {
		return
	}
	it.ListID = id
	it, err := s.store.CreateItem(it)
	respond(w, http.StatusCreated, it, err)
}

func (s *Server) clearDone(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	n, err := s.store.ClearDone(id)
	respond(w, http.StatusOK, map[string]int64{"deleted": n}, err)
}

func (s *Server) updateItem(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var it store.Item
	if !decode(w, r, &it) {
		return
	}
	it.ID = id
	it, err := s.store.UpdateItem(it)
	respond(w, http.StatusOK, it, err)
}

func (s *Server) deleteItem(w http.ResponseWriter, r *http.Request) {
	if id, ok := pathID(w, r); ok {
		noContent(w, s.store.DeleteItem(id))
	}
}

// --- Journal ---

func (s *Server) listJournal(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	entries, err := s.store.ListJournal(q.Get("from"), q.Get("to"))
	respond(w, http.StatusOK, entries, err)
}

func (s *Server) getJournal(w http.ResponseWriter, r *http.Request) {
	date, ok := pathDate(w, r)
	if !ok {
		return
	}
	j, err := s.store.GetJournal(date)
	respond(w, http.StatusOK, j, err)
}

func (s *Server) putJournal(w http.ResponseWriter, r *http.Request) {
	date, ok := pathDate(w, r)
	if !ok {
		return
	}
	var j store.JournalEntry
	if !decode(w, r, &j) {
		return
	}
	j.Date = date
	j, err := s.store.PutJournal(j)
	respond(w, http.StatusOK, j, err)
}

func (s *Server) deleteJournal(w http.ResponseWriter, r *http.Request) {
	if date, ok := pathDate(w, r); ok {
		noContent(w, s.store.DeleteJournal(date))
	}
}

// --- Period ---

func (s *Server) listPeriod(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	days, err := s.store.ListPeriod(q.Get("from"), q.Get("to"))
	respond(w, http.StatusOK, days, err)
}

func (s *Server) periodSummary(w http.ResponseWriter, r *http.Request) {
	sum, err := s.store.CycleSummary(s.today())
	respond(w, http.StatusOK, sum, err)
}

func (s *Server) putPeriod(w http.ResponseWriter, r *http.Request) {
	date, ok := pathDate(w, r)
	if !ok {
		return
	}
	var p store.PeriodDay
	if !decode(w, r, &p) {
		return
	}
	p.Date = date
	p, err := s.store.PutPeriod(p)
	respond(w, http.StatusOK, p, err)
}

func (s *Server) deletePeriod(w http.ResponseWriter, r *http.Request) {
	if date, ok := pathDate(w, r); ok {
		noContent(w, s.store.DeletePeriod(date))
	}
}

// --- Trackers ---

func (s *Server) listTrackers(w http.ResponseWriter, r *http.Request) {
	trackers, err := s.store.ListTrackers(r.URL.Query().Get("archived") == "1")
	respond(w, http.StatusOK, trackers, err)
}

func (s *Server) createTracker(w http.ResponseWriter, r *http.Request) {
	var t store.Tracker
	if !decode(w, r, &t) {
		return
	}
	t, err := s.store.CreateTracker(t)
	respond(w, http.StatusCreated, t, err)
}

func (s *Server) updateTracker(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var t store.Tracker
	if !decode(w, r, &t) {
		return
	}
	t.ID = id
	t, err := s.store.UpdateTracker(t)
	respond(w, http.StatusOK, t, err)
}

func (s *Server) deleteTracker(w http.ResponseWriter, r *http.Request) {
	if id, ok := pathID(w, r); ok {
		noContent(w, s.store.DeleteTracker(id))
	}
}

func (s *Server) listEntries(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	entries, err := s.store.ListEntries(id, q.Get("from"), q.Get("to"))
	respond(w, http.StatusOK, entries, err)
}

func (s *Server) putEntry(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	date, ok := pathDate(w, r)
	if !ok {
		return
	}
	var e store.TrackerEntry
	if !decode(w, r, &e) {
		return
	}
	e.TrackerID, e.Date = id, date
	e, err := s.store.PutEntry(e)
	respond(w, http.StatusOK, e, err)
}

func (s *Server) deleteEntry(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	if date, ok := pathDate(w, r); ok {
		noContent(w, s.store.DeleteEntry(id, date))
	}
}
