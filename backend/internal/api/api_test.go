package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/MorgensternMA/diario/backend/internal/store"
)

func newTestServer(t *testing.T, token string) http.Handler {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	srv := &Server{store: st, token: token, now: func() time.Time {
		return time.Date(2026, 10, 16, 12, 0, 0, 0, time.UTC)
	}}
	return srv.routes()
}

func do(t *testing.T, h http.Handler, method, path string, body any, out any) int {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, &buf)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if out != nil && rec.Code < 300 {
		if err := json.Unmarshal(rec.Body.Bytes(), out); err != nil {
			t.Fatalf("%s %s: decode %q: %v", method, path, rec.Body.String(), err)
		}
	}
	return rec.Code
}

func TestSeededDefaults(t *testing.T) {
	h := newTestServer(t, "")
	var cats []store.Category
	do(t, h, "GET", "/api/categories", nil, &cats)
	var lists []store.List
	do(t, h, "GET", "/api/lists", nil, &lists)
	var trackers []store.Tracker
	do(t, h, "GET", "/api/trackers", nil, &trackers)
	if len(cats) != 4 || len(lists) != 3 || len(trackers) != 3 {
		t.Fatalf("seed: %d categories, %d lists, %d trackers", len(cats), len(lists), len(trackers))
	}
}

func TestDayAggregate(t *testing.T) {
	h := newTestServer(t, "")

	var cat store.Category
	do(t, h, "POST", "/api/categories", map[string]any{"name": "Facultad", "color": "#FF0000"}, &cat)

	var ev store.Event
	code := do(t, h, "POST", "/api/events", map[string]any{
		"title": "Final de Análisis", "date": "2026-10-20", "time": "09:30", "category_id": cat.ID,
	}, &ev)
	if code != http.StatusCreated || ev.ID == 0 {
		t.Fatalf("create event: %d %+v", code, ev)
	}
	if code := do(t, h, "POST", "/api/events", map[string]any{"title": "x", "date": "20-10-2026"}, nil); code != http.StatusBadRequest {
		t.Errorf("bad date accepted: %d", code)
	}

	do(t, h, "PUT", "/api/journal/2026-10-20", map[string]any{"mood": 4, "feelings": []string{"tranquila"}, "note": "buen día"}, nil)
	do(t, h, "PUT", "/api/period/2026-10-20", map[string]any{"flow": 3, "symptoms": []string{"cólicos"}}, nil)
	do(t, h, "PUT", "/api/trackers/1/entries/2026-10-20", map[string]any{"value": 6}, nil)

	var lists []store.List
	do(t, h, "GET", "/api/lists", nil, &lists)
	do(t, h, "POST", "/api/lists/"+itoa(lists[2].ID)+"/items", map[string]any{"text": "Cubiertos", "due_date": "2026-10-20"}, nil)

	var day store.Day
	if code := do(t, h, "GET", "/api/day/2026-10-20", nil, &day); code != http.StatusOK {
		t.Fatalf("day: %d", code)
	}
	if len(day.Events) != 1 || day.Journal == nil || day.Journal.Mood != 4 || day.Period == nil || day.Period.Flow != 3 {
		t.Fatalf("day = %+v", day)
	}
	if day.Trackers[0].Value == nil || *day.Trackers[0].Value != 6 || day.Trackers[1].Value != nil {
		t.Errorf("trackers = %+v", day.Trackers)
	}
	if len(day.DueItems) != 1 || day.DueItems[0].Text != "Cubiertos" {
		t.Errorf("due items = %+v", day.DueItems)
	}

	var cal []store.CalendarDay
	do(t, h, "GET", "/api/calendar?from=2026-10-01&to=2026-11-30", nil, &cal)
	found := false
	for _, d := range cal {
		if d.Date == "2026-10-20" {
			found = true
			if len(d.Events) != 1 || d.Events[0].Color != "#FF0000" || d.Mood != 4 || d.Flow != 3 || d.DueItems != 1 {
				t.Errorf("calendar day = %+v", d)
			}
		}
	}
	if !found {
		t.Error("2026-10-20 missing from calendar")
	}
	// Next period predicted 28 days after 2026-10-20.
	predicted := false
	for _, d := range cal {
		if d.Date == "2026-11-17" && d.PredictedPeriod {
			predicted = true
		}
	}
	if !predicted {
		t.Error("expected predicted period on 2026-11-17")
	}

	// Deleting the category keeps the event, uncategorized.
	do(t, h, "DELETE", "/api/categories/"+itoa(cat.ID), nil, nil)
	var events []store.Event
	do(t, h, "GET", "/api/events?from=2026-10-20&to=2026-10-20", nil, &events)
	if len(events) != 1 || events[0].CategoryID != nil {
		t.Errorf("events after category delete = %+v", events)
	}
}

func TestItemsLifecycle(t *testing.T) {
	h := newTestServer(t, "")
	var l store.List
	do(t, h, "POST", "/api/lists", map[string]any{"name": "Viaje", "kind": "custom"}, &l)
	base := "/api/lists/" + itoa(l.ID)

	var a, b store.Item
	do(t, h, "POST", base+"/items", map[string]any{"text": "Pasaporte"}, &a)
	do(t, h, "POST", base+"/items", map[string]any{"text": "Cargador", "quantity": "2"}, &b)
	a.Done = true
	do(t, h, "PUT", "/api/items/"+itoa(a.ID), a, nil)

	var items []store.Item
	do(t, h, "GET", base+"/items", nil, &items)
	if len(items) != 2 || items[0].ID != b.ID {
		t.Fatalf("pending items should come first: %+v", items)
	}

	var res map[string]int
	do(t, h, "POST", base+"/clear-done", nil, &res)
	if res["deleted"] != 1 {
		t.Errorf("clear-done = %+v", res)
	}
	if code := do(t, h, "POST", "/api/lists/999/items", map[string]any{"text": "x"}, nil); code != http.StatusNotFound {
		t.Errorf("item on missing list: %d", code)
	}
}

func TestAuth(t *testing.T) {
	h := newTestServer(t, "secret")
	if code := do(t, h, "GET", "/api/lists", nil, nil); code != http.StatusUnauthorized {
		t.Errorf("no token: %d", code)
	}
	if code := do(t, h, "GET", "/api/health", nil, nil); code != http.StatusOK {
		t.Errorf("health should be public: %d", code)
	}
	req := httptest.NewRequest("GET", "/api/lists", nil)
	req.Header.Set("Authorization", "Bearer secret")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Errorf("with token: %d", rec.Code)
	}
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }
