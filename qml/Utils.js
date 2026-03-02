.pragma library

function formatBytes(b) {
    if (b <= 0) return "";
    if (b >= 1073741824) return "~ " + (b / 1073741824).toFixed(1) + " Gb";
    if (b >= 1048576)    return "~ " + (b / 1048576).toFixed(1) + " Mb";
    if (b >= 1024)       return "~ " + (b / 1024).toFixed(1) + " Kb";
    return "~ " + b + " B";
}
