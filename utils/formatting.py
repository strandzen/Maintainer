def format_bytes(total_bytes: int) -> str:
    """Format a byte count into a human-readable string (e.g. '1.2G', '48.1M')."""
    if total_bytes <= 0:
        return ""
    if total_bytes >= 1024 ** 3:
        return f"{total_bytes / (1024 ** 3):.1f}G"
    if total_bytes >= 1024 ** 2:
        return f"{total_bytes / (1024 ** 2):.1f}M"
    if total_bytes >= 1024:
        return f"{total_bytes / 1024:.1f}K"
    return f"{total_bytes}B"
