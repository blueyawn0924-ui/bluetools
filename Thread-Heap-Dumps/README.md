# Thread & Heap Dump Tool

This folder contains a Windows PowerShell GUI tool for collecting Java thread dumps, heap dumps, and pod logs from a Kubernetes pod.

## Files

- `k8s_dump_tool_final_debug.ps1`
  - Main GUI script.
  - Uses `kubectl` to discover namespaces, pods, containers, and Java processes.
  - Collects thread dumps, heap dump, and pod logs.
  - Defaults output to `./dumps` relative to this folder.

- `run_k8s_dump_tool.bat`
  - Launcher script that runs the PowerShell GUI with `-ExecutionPolicy Bypass`.
  - Use this file to avoid manual execution policy steps.

- `Howtorun.txt`
  - Previous usage note for the script.

## Usage

1. Open a command prompt or PowerShell window.
2. Change directory to this folder:
   ```powershell
   cd path\to\envbackups\operations\scripts\Thread-Heap-Dumps
   ```
3. Run the launcher:
   ```bat
   run_k8s_dump_tool.bat
   ```
4. In the GUI:
   - Select your kubeconfig file.
   - Choose a namespace, pod, container, and Java process.
   - Verify the output folder is set to `./dumps`.
   - Set the thread dump count and interval as needed.
   - Click `Run Collection`.

## Output

- Files are saved into the `dumps` directory relative to this script.
- The script also preserves the original JVM-generated files under `/tmp` inside the target pod.

## Requirements

- `kubectl` available in `PATH`
- Access to the target Kubernetes cluster
- Java process running inside the selected pod
- Windows PowerShell

## Notes

- If you prefer a different output location, choose a folder using the GUI Browse button.
- The launcher handles `-ExecutionPolicy Bypass`, so no manual policy change is required.
