try {
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8000
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
$listener.Start()

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css" = "text/css; charset=utf-8"
    ".js" = "application/javascript; charset=utf-8"
    ".png" = "image/png"
    ".jpg" = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".svg" = "image/svg+xml"
    ".ico" = "image/x-icon"
}

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $reader = [System.IO.StreamReader]::new($stream)
        $requestLine = $reader.ReadLine()

        while (($line = $reader.ReadLine()) -ne $null -and $line -ne "") {}

        $path = "index.html"
        if ($requestLine -match "^[A-Z]+\s+([^\s]+)") {
            $path = [System.Uri]::UnescapeDataString($matches[1].Split("?")[0].TrimStart("/"))
            if ([string]::IsNullOrWhiteSpace($path)) {
                $path = "index.html"
            }
        }

        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $root $path))
        $rootPath = [System.IO.Path]::GetFullPath($root)

        if (-not $fullPath.StartsWith($rootPath) -or -not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            $body = [System.Text.Encoding]::UTF8.GetBytes("Not found")
            $header = "HTTP/1.1 404 Not Found`r`nContent-Length: $($body.Length)`r`nContent-Type: text/plain; charset=utf-8`r`nConnection: close`r`n`r`n"
        } else {
            $body = [System.IO.File]::ReadAllBytes($fullPath)
            $extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
            $mime = $mimeTypes[$extension]
            if (-not $mime) {
                $mime = "application/octet-stream"
            }
            $header = "HTTP/1.1 200 OK`r`nContent-Length: $($body.Length)`r`nContent-Type: $mime`r`nConnection: close`r`n`r`n"
        }

        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($body, 0, $body.Length)
    } finally {
        $client.Close()
    }
}
} catch {
    $_ | Out-File -LiteralPath (Join-Path $PSScriptRoot "mobile-server-error.log") -Encoding utf8
    Start-Sleep -Seconds 20
}
