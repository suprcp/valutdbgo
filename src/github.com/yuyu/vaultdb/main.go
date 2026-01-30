package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"

	httpd "github.com/yuyu/vaultdb/http"
	"github.com/yuyu/vaultdb/store"
)

// Command line defaults
const (
	DefaultHTTPAddr = "localhost:11000"
	DefaultRaftAddr = "localhost:12000"
)

// Command line parameters
var (
	inmem    bool
	httpAddr string
	raftAddr string
	joinAddr string
	nodeID   string
)

func init() {
	flag.BoolVar(&inmem, "inmem", false, "Use in-memory storage for Raft")
	flag.StringVar(&httpAddr, "haddr", DefaultHTTPAddr, "Set the HTTP bind address")
	flag.StringVar(&raftAddr, "raddr", DefaultRaftAddr, "Set Raft bind address")
	flag.StringVar(&joinAddr, "join", "", "Set join address, if any")
	flag.StringVar(&nodeID, "id", "", "Node ID. If not set, same as Raft bind address")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <raft-data-path> \n", os.Args[0])
		flag.PrintDefaults()
	}
}

func main() {
	flag.Parse()
	if flag.NArg() == 0 {
		fmt.Fprintf(os.Stderr, "No Raft storage directory specified\n")
		os.Exit(1)
	}

	if nodeID == "" {
		nodeID = raftAddr
	}

	// Ensure Raft storage exists.
	raftDir := flag.Arg(0)
	if raftDir == "" {
		log.Fatalln("No Raft storage directory specified")
	}
	if err := os.MkdirAll(raftDir, 0o700); err != nil {
		log.Fatalf("failed to create path for Raft storage: %s", err.Error())
	}

	s := store.New(inmem)
	s.RaftDir = raftDir
	s.RaftBind = raftAddr
	if err := s.Open(joinAddr == "", nodeID); err != nil {
		log.Fatalf("failed to open store: %s", err.Error())
	}

	h := httpd.New(httpAddr, s)
	if err := h.Start(); err != nil {
		log.Fatalf("failed to start HTTP service: %s", err.Error())
	}

	// If join was specified, make the join request.
	if joinAddr != "" {
		if err := join(joinAddr, raftAddr, nodeID); err != nil {
			log.Fatalf("failed to join node at %s: %s", joinAddr, err.Error())
		}
	}

	// We're up and running!
	log.Printf("VaultDB started successfully, listening on http://%s", httpAddr)

	terminate := make(chan os.Signal, 1)
	signal.Notify(terminate, os.Interrupt)
	<-terminate
	log.Println("VaultDB exiting")
	
	// Cleanup
	h.Close()
	if err := s.Close(); err != nil {
		log.Printf("error closing store: %v", err)
	}
}

func join(joinAddr, raftAddr, nodeID string) error {
	// Normalize join address - if it starts with ':', prepend 'localhost'
	normalizedAddr := joinAddr
	if strings.HasPrefix(joinAddr, ":") {
		normalizedAddr = "localhost" + joinAddr
	}
	
	b, err := json.Marshal(map[string]string{"addr": raftAddr, "id": nodeID})
	if err != nil {
		return err
	}
	
	url := fmt.Sprintf("http://%s/join", normalizedAddr)
	log.Printf("attempting to join cluster at %s", url)
	
	resp, err := http.Post(url, "application-type/json", bytes.NewReader(b))
	if err != nil {
		return fmt.Errorf("failed to connect to join address %s: %w", normalizedAddr, err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("join request failed with status %d: %s", resp.StatusCode, string(body))
	}
	
	log.Printf("successfully joined cluster at %s", normalizedAddr)
	return nil
}
