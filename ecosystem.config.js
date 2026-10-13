module.exports = {
  apps: [
    {
      name: "cybra-autonode",
      script: "/data/data/com.termux/files/home/CYBRA/modules/module_114_autonode/daemon.py",
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true, max_restarts: 20, restart_delay: 3000,
      out_file: "/data/data/com.termux/files/home/CYBRA/logs/autonode.out.log",
      error_file: "/data/data/com.termux/files/home/CYBRA/logs/autonode.err.log",
      merge_logs: true, time: true
    },
    {
      name: "cybra-watchdog",
      script: "/data/data/com.termux/files/home/CYBRA/modules/module_121_parlament/watchdog.sh",
      args: "daemon", interpreter: "bash", cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true, restart_delay: 5000,
      out_file: "/data/data/com.termux/files/home/CYBRA/logs/watchdog.out.log",
      error_file: "/data/data/com.termux/files/home/CYBRA/logs/watchdog.err.log",
      merge_logs: true, time: true
    },
    {
      name: "cybra-orchestrator",
      script: "/data/data/com.termux/files/home/CYBRA/modules/module_121_parlament/orchestrator.py",
      args: "daemon --interval 600", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true, restart_delay: 5000,
      out_file: "/data/data/com.termux/files/home/CYBRA/logs/orch.out.log",
      error_file: "/data/data/com.termux/files/home/CYBRA/logs/orch.err.log",
      merge_logs: true, time: true
    },
    {
      name: "cybra-executor",
      script: "/data/data/com.termux/files/home/CYBRA/modules/module_121_parlament/executor.py",
      args: "auto", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true, restart_delay: 5000,
      out_file: "/data/data/com.termux/files/home/CYBRA/logs/exec.out.log",
      error_file: "/data/data/com.termux/files/home/CYBRA/logs/exec.err.log",
      merge_logs: true, time: true
    }
  ]
};
