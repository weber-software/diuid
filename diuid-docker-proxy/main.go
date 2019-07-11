package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"syscall"
)

const (
	realProxy       = "docker-proxy"
	diuidParentHost = "10.0.2.2"
)

// drop-in replacement for docker-proxy.
//
// forked from https://github.com/rootless-containers/rootlesskit/blob/v0.6.0/cmd/rootlesskit-docker-proxy/main.go
// (relicensed to GPL3 by the author)
func main() {
	containerIP := flag.String("container-ip", "", "container ip")
	containerPort := flag.Int("container-port", -1, "container port")
	hostIP := flag.String("host-ip", "", "host ip")
	hostPort := flag.Int("host-port", -1, "host port")
	proto := flag.String("proto", "tcp", "proxy protocol")
	flag.Parse()

	if *proto != "tcp" {
		log.Fatalf("unsupported proto: %q", proto)
	}

	cmd := exec.Command(realProxy,
		"-container-ip", *containerIP,
		"-container-port", strconv.Itoa(*containerPort),
		"-host-ip", "127.0.0.1",
		"-host-port", strconv.Itoa(*hostPort),
		"-proto", *proto)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Pdeathsig: syscall.SIGKILL,
	}
	if err := cmd.Start(); err != nil {
		log.Fatal(err)
	}

	sshFlags := []string{"-N", "-o", "StrictHostKeyChecking=no"}
	sshFlags = append(sshFlags, fmt.Sprintf("-R%s:%d:0.0.0.0:%d", *hostIP, *hostPort, *hostPort))
	sshFlags = append(sshFlags, diuidParentHost)
	sshCmd := exec.Command("ssh", sshFlags...)
	sshCmd.Env = os.Environ()
	sshCmd.SysProcAttr = &syscall.SysProcAttr{
		Pdeathsig: syscall.SIGKILL,
	}
	if err := sshCmd.Start(); err != nil {
		log.Fatal(err)
	}
	defer sshCmd.Process.Kill()

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, os.Interrupt)
	<-ch
	if err := cmd.Process.Kill(); err != nil {
		log.Fatal(err)
	}
}
