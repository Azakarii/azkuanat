$root = (Resolve-Path $PSScriptRoot).Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://localhost:8000/')

try {
    $listener.Start()
} catch {
    Write-Host "Could not start the local server on port 8000."
    Write-Host $_.Exception.Message
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host "Anatomy Atlas is running at http://localhost:8000/"
Start-Process 'http://localhost:8000/'

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.js' = 'text/javascript; charset=utf-8'
    '.css' = 'text/css; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.webmanifest' = 'application/manifest+json'
    '.svg' = 'image/svg+xml'
    '.glb' = 'model/gltf-binary'
    '.png' = 'image/png'
    '.jpg' = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
    if ($relative.EndsWith('/') -or [string]::IsNullOrWhiteSpace([IO.Path]::GetExtension($relative))) {
        $relative = [IO.Path]::Combine($relative, 'index.html')
    }

    $path = [IO.Path]::GetFullPath([IO.Path]::Combine($root, $relative.Replace('/', '\')))
    if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($path)) {
        $context.Response.StatusCode = 404
        $context.Response.Close()
        continue
    }

    $body = [IO.File]::ReadAllBytes($path)
    $extension = [IO.Path]::GetExtension($path).ToLowerInvariant()
    $context.Response.StatusCode = 200
    $context.Response.ContentType = if ($mime.ContainsKey($extension)) { $mime[$extension] } else { 'application/octet-stream' }
    $context.Response.ContentLength64 = $body.Length
    $context.Response.Headers.Add('Cache-Control', 'no-cache')
    $context.Response.OutputStream.Write($body, 0, $body.Length)
    $context.Response.OutputStream.Close()
}
