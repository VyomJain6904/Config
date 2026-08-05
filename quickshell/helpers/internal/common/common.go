package common

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

type Result struct {
	Stdout string
	Stderr string
	Code   int
}

func Run(timeout time.Duration, name string, args ...string) Result {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, name, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	code := 0
	if err != nil {
		code = ExitCode(err)
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			if stderr.Len() > 0 && !strings.HasSuffix(stderr.String(), "\n") {
				stderr.WriteByte('\n')
			}
			fmt.Fprintf(&stderr, "%s timed out after %s", name, timeout)
		} else if stderr.Len() == 0 {
			stderr.WriteString(err.Error())
		}
	}
	return Result{Stdout: stdout.String(), Stderr: stderr.String(), Code: code}
}

func RunOutput(timeout time.Duration, name string, args ...string) string {
	return Run(timeout, name, args...).Stdout
}

func RunAttached(name string, args ...string) int {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return ExitCode(cmd.Run())
}

func StartDetached(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return cmd.Start()
}

func ReplaceProcess(name string, args ...string) error {
	path, err := exec.LookPath(name)
	if err != nil {
		return err
	}
	return syscall.Exec(path, append([]string{name}, args...), os.Environ())
}

func ExitCode(err error) int {
	if err == nil {
		return 0
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode()
	}
	return 1
}

func PrintResult(result Result) {
	_, _ = io.WriteString(os.Stdout, result.Stdout)
	_, _ = io.WriteString(os.Stderr, result.Stderr)
}

func HomeDir() string {
	if home, err := os.UserHomeDir(); err == nil {
		return home
	}
	if home := os.Getenv("HOME"); home != "" {
		return home
	}
	return "/home/jain"
}

func ReadJSON(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func WriteJSON(path string, value any, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	tmp, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)

	if err := tmp.Chmod(mode); err != nil {
		_ = tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, path)
}

func FileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func ExecutableExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func Bool01(value bool) string {
	if value {
		return "1"
	}
	return "0"
}

func YesNo(value bool) string {
	if value {
		return "yes"
	}
	return "no"
}
