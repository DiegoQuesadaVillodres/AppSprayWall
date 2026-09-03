# Prepara las fotos de los muros para la app.
#
# Entrada:  Imagenes/Recortadas/*.JPG  (encuadradas a mano, ya orientadas)
# Salida:   Imagenes/web/*.jpg         (lado mayor 2400 px, JPEG q82)
#
# Los originales de cámara están en Imagenes/*.JPG y venían tumbados 90º; las recortadas
# ya salen derechas, así que aquí solo se reescala y se comprime. Las 4 fotos tienen
# proporciones distintas y se conservan tal cual: la app lee el aspecto real de cada
# imagen, no asume ninguno.
#
# Uso:  pwsh -File scripts/preparar-imagenes.ps1

Add-Type -AssemblyName System.Drawing

$raiz    = Split-Path -Parent $PSScriptRoot
$origen  = Join-Path $raiz "Imagenes\Recortadas"
$destino = Join-Path $raiz "Imagenes\web"

New-Item -ItemType Directory -Force $destino | Out-Null

# nombre recortado -> nombre en la app (debe coincidir con la columna `imagen` de la tabla walls)
$mapa = [ordered]@{
    "SprayWall_p.JPG" = "spraywall.jpg"
    "Muro0º_p.JPG"    = "muro-0.jpg"
    "Muro5º_p.JPG"     = "muro-5.jpg"
    "Muro15º_p.JPG"    = "muro-15.jpg"
}

$maxLado = 2400
$calidad = 82L

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
         Where-Object { $_.MimeType -eq 'image/jpeg' }

foreach ($original in $mapa.Keys) {
    $rutaOrigen = Join-Path $origen $original
    if (-not (Test-Path $rutaOrigen)) {
        Write-Warning "No encuentro $original, lo salto."
        continue
    }

    $img = [System.Drawing.Image]::FromFile($rutaOrigen)
    try {
        # Reescala por el lado mayor, conservando la proporción original.
        $escala = $maxLado / [Math]::Max($img.Width, $img.Height)
        if ($escala -gt 1) { $escala = 1 }   # nunca ampliar
        $ancho = [int]($img.Width  * $escala)
        $alto  = [int]($img.Height * $escala)

        $bmp = New-Object System.Drawing.Bitmap($ancho, $alto)
        $g   = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.DrawImage($img, 0, 0, $ancho, $alto)

            $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
                [System.Drawing.Imaging.Encoder]::Quality, $calidad)

            $rutaDestino = Join-Path $destino $mapa[$original]
            $bmp.Save($rutaDestino, $codec, $ep)

            $kb = [math]::Round((Get-Item $rutaDestino).Length / 1KB)
            Write-Output ("{0,-18} -> {1,-15} {2}x{3}  {4} KB" -f $original, $mapa[$original], $ancho, $alto, $kb)
        }
        finally { $g.Dispose(); $bmp.Dispose() }
    }
    finally { $img.Dispose() }
}

Write-Output ""
Write-Output "Listo. Sube los archivos de Imagenes/web/ a public/walls/ en el proyecto de Lovable."
Write-Output "Recuerda: si cambia el encuadre, los bloques ya guardados de ese muro quedan descolocados."
