// Command diario serves the Diario API.
//
// Configuration (flags override environment variables):
//
//	-addr  / DIARIO_ADDR   listen address (default ":8484")
//	-db    / DIARIO_DB     SQLite file (default "diario.db")
//	-token / DIARIO_TOKEN  optional bearer token required by every request
package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/MorgensternMA/diario/backend/internal/api"
	"github.com/MorgensternMA/diario/backend/internal/store"
)

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	addr := flag.String("addr", env("DIARIO_ADDR", ":8484"), "listen address")
	dbPath := flag.String("db", env("DIARIO_DB", "diario.db"), "SQLite database file")
	token := flag.String("token", env("DIARIO_TOKEN", ""), "bearer token (optional)")
	flag.Parse()

	st, err := store.Open(*dbPath)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer st.Close()

	srv := &http.Server{
		Addr:              *addr,
		Handler:           api.New(st, *token),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		srv.Shutdown(shutdownCtx)
	}()

	log.Printf("Diario API listening on %s (db: %s, auth: %v)", *addr, *dbPath, *token != "")
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
