// Package api exposes the store over a JSON HTTP API.
package api

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/MorgensternMA/diario/backend/internal/store"
)

type Server struct {
	store *store.Store
	token string
	// now is swappable for tests.
	now func() time.Time
}

// New builds the HTTP handler. When token is non-empty every /api request
// must send "Authorization: Bearer <token>".
func New(s *store.Store, token string) http.Handler {
	srv := &Server{store: s, token: token, now: time.Now}
	return srv.routes()
}

func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	mux.HandleFunc("GET /api/day/{date}", s.getDay)
	mux.HandleFunc("GET /api/calendar", s.getCalendar)

	mux.HandleFunc("GET /api/categories", s.listCategories)
	mux.HandleFunc("POST /api/categories", s.createCategory)
	mux.HandleFunc("PUT /api/categories/{id}", s.updateCategory)
	mux.HandleFunc("DELETE /api/categories/{id}", s.deleteCategory)

	mux.HandleFunc("GET /api/events", s.listEvents)
	mux.HandleFunc("POST /api/events", s.createEvent)
	mux.HandleFunc("PUT /api/events/{id}", s.updateEvent)
	mux.HandleFunc("DELETE /api/events/{id}", s.deleteEvent)

	mux.HandleFunc("GET /api/lists", s.listLists)
	mux.HandleFunc("POST /api/lists", s.createList)
	mux.HandleFunc("PUT /api/lists/{id}", s.updateList)
	mux.HandleFunc("DELETE /api/lists/{id}", s.deleteList)
	mux.HandleFunc("GET /api/lists/{id}/items", s.listItems)
	mux.HandleFunc("POST /api/lists/{id}/items", s.createItem)
	mux.HandleFunc("POST /api/lists/{id}/clear-done", s.clearDone)
	mux.HandleFunc("PUT /api/items/{id}", s.updateItem)
	mux.HandleFunc("DELETE /api/items/{id}", s.deleteItem)

	mux.HandleFunc("GET /api/journal", s.listJournal)
	mux.HandleFunc("GET /api/journal/{date}", s.getJournal)
	mux.HandleFunc("PUT /api/journal/{date}", s.putJournal)
	mux.HandleFunc("DELETE /api/journal/{date}", s.deleteJournal)

	mux.HandleFunc("GET /api/period", s.listPeriod)
	mux.HandleFunc("GET /api/period/summary", s.periodSummary)
	mux.HandleFunc("PUT /api/period/{date}", s.putPeriod)
	mux.HandleFunc("DELETE /api/period/{date}", s.deletePeriod)

	mux.HandleFunc("GET /api/trackers", s.listTrackers)
	mux.HandleFunc("POST /api/trackers", s.createTracker)
	mux.HandleFunc("PUT /api/trackers/{id}", s.updateTracker)
	mux.HandleFunc("DELETE /api/trackers/{id}", s.deleteTracker)
	mux.HandleFunc("GET /api/trackers/{id}/entries", s.listEntries)
	mux.HandleFunc("PUT /api/trackers/{id}/entries/{date}", s.putEntry)
	mux.HandleFunc("DELETE /api/trackers/{id}/entries/{date}", s.deleteEntry)

	return s.cors(s.auth(mux))
}

func (s *Server) auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.token != "" && r.URL.Path != "/api/health" {
			want := "Bearer " + s.token
			if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), []byte(want)) != 1 {
				writeError(w, http.StatusUnauthorized, "unauthorized")
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

// cors lets the Flutter web build talk to the API from another origin.
func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Access-Control-Allow-Origin", "*")
		h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		h.Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) today() time.Time { return s.now() }

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("encode response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// fail maps store errors to HTTP status codes.
func fail(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "not found")
	case errors.Is(err, store.ErrInvalid):
		writeError(w, http.StatusBadRequest, err.Error())
	default:
		log.Printf("internal error: %v", err)
		writeError(w, http.StatusInternalServerError, "internal error")
	}
}

func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return false
	}
	return true
}

func pathID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "invalid id")
		return 0, false
	}
	return id, true
}

func pathDate(w http.ResponseWriter, r *http.Request) (string, bool) {
	date := r.PathValue("date")
	if _, err := store.ParseDate(date); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return "", false
	}
	return date, true
}

// respond writes v with the given status, or the mapped error.
func respond(w http.ResponseWriter, status int, v any, err error) {
	if err != nil {
		fail(w, err)
		return
	}
	writeJSON(w, status, v)
}

func noContent(w http.ResponseWriter, err error) {
	if err != nil {
		fail(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
