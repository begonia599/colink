package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"
	"time"
)

// App struct
type App struct {
	ctx        context.Context
	kcpProcess *exec.Cmd
	mu         sync.Mutex
	connected  bool
}

// NodeConfig 节点配置
type NodeConfig struct {
	Server    string `json:"server"`
	Port      int    `json:"port"`
	Key       string `json:"key"`
	Crypt     string `json:"crypt"`
	Mode      string `json:"mode"`
	LocalPort int    `json:"localPort"`
}

// ConnectionStatus 连接状态
type ConnectionStatus struct {
	Connected bool   `json:"connected"`
	LocalPort int    `json:"localPort"`
	Error     string `json:"error,omitempty"`
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// shutdown is called when the app is closing
func (a *App) shutdown(ctx context.Context) {
	a.Disconnect()
}

// Connect 连接到 KCP 节点
func (a *App) Connect(config NodeConfig) ConnectionStatus {
	a.mu.Lock()
	defer a.mu.Unlock()

	// 如果已经连接，先断开
	if a.kcpProcess != nil {
		a.disconnectInternal()
	}

	// 获取 kcptun 客户端路径
	exePath, err := os.Executable()
	if err != nil {
		return ConnectionStatus{Connected: false, Error: fmt.Sprintf("获取程序路径失败: %v", err)}
	}
	kcpPath := filepath.Join(filepath.Dir(exePath), "kcptun.exe")

	// 检查 kcptun 是否存在
	if _, err := os.Stat(kcpPath); os.IsNotExist(err) {
		// 尝试当前目录
		kcpPath = "kcptun.exe"
		if _, err := os.Stat(kcpPath); os.IsNotExist(err) {
			return ConnectionStatus{Connected: false, Error: "找不到 kcptun.exe"}
		}
	}

	// 构建参数
	localPort := config.LocalPort
	if localPort == 0 {
		localPort = 25565
	}

	args := []string{
		"-r", fmt.Sprintf("%s:%d", config.Server, config.Port),
		"-l", fmt.Sprintf(":%d", localPort),
		"-key", config.Key,
		"-crypt", config.Crypt,
		"-mode", config.Mode,
		"-mtu", "1350",
		"-sndwnd", "2048",
		"-rcvwnd", "2048",
		"-datashard", "10",
		"-parityshard", "3",
		"-nocomp",
	}

	// 启动 kcptun 客户端
	a.kcpProcess = exec.Command(kcpPath, args...)
	a.kcpProcess.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}

	if err := a.kcpProcess.Start(); err != nil {
		a.kcpProcess = nil
		return ConnectionStatus{Connected: false, Error: fmt.Sprintf("启动 kcptun 失败: %v", err)}
	}

	// 等待一小段时间检查进程是否正常运行
	time.Sleep(500 * time.Millisecond)

	if a.kcpProcess.ProcessState != nil && a.kcpProcess.ProcessState.Exited() {
		a.kcpProcess = nil
		return ConnectionStatus{Connected: false, Error: "kcptun 进程异常退出"}
	}

	a.connected = true
	return ConnectionStatus{Connected: true, LocalPort: localPort}
}

// Disconnect 断开连接
func (a *App) Disconnect() ConnectionStatus {
	a.mu.Lock()
	defer a.mu.Unlock()

	a.disconnectInternal()
	return ConnectionStatus{Connected: false}
}

func (a *App) disconnectInternal() {
	if a.kcpProcess != nil && a.kcpProcess.Process != nil {
		a.kcpProcess.Process.Kill()
		a.kcpProcess.Wait()
		a.kcpProcess = nil
	}
	a.connected = false
}

// GetStatus 获取当前连接状态
func (a *App) GetStatus() ConnectionStatus {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.kcpProcess == nil {
		return ConnectionStatus{Connected: false}
	}

	// 检查进程是否还在运行
	if a.kcpProcess.ProcessState != nil && a.kcpProcess.ProcessState.Exited() {
		a.kcpProcess = nil
		a.connected = false
		return ConnectionStatus{Connected: false, Error: "连接已断开"}
	}

	return ConnectionStatus{Connected: a.connected}
}
