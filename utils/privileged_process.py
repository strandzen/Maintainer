import subprocess

def run_privileged(command_list, description="Maintainer Task"):
    """
    Wraps a command list with pkexec.
    Using 'sh -c' allows complex pipelines or shell builtins if needed, 
    but for security it's better to pass the exact command.
    """
    # Assuming CachyOS/Arch with polkit installed
    pkexec_cmd = ["pkexec"] + command_list
    
    try:
        # We use Popen so the caller can read stdout/stderr or wait
        process = subprocess.Popen(
            pkexec_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return process
    except Exception as e:
        print(f"Failed to start privileged process: {e}")
        return None
