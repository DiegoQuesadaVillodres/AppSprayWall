# Prepara las fotos de los muros para la app.
#
# Entrada:  Imagenes/Recortadas/*.JPG  (encuadradas a mano, ya orientadas)
#           Imagenes/PanoSprayBIG.jpg  (la panorámica, sin recortar)
# Salida:   Imagenes/web/*.jpg
#
# Los originales de cámara están en Imagenes/*.JPG y venían tumbados 90º; las recortadas
# ya salen derechas, así que aquí solo se reescala y se comprime. Las fotos tienen
# proporciones distintas y se conservan tal cual: la app lee el aspecto real de cada
# imagen, no asume ninguno.
#
# Cada foto lleva SU tamaño, y esa es la única sutileza del script: los cuatro paneles
# van a 2400 px porque encuadran un muro, pero la panorámica abarca la sala entera, así
# que a 2400 cada presa quedaría en unos 20 px y sería imposible marcarla. Va a 8000 px
# y calidad 92, que es lo que aguanta el zoom hasta x16 del visor panorámico.
#
# Uso:  pwsh -File scripts/preparar-imagenes.ps1

Add-Type -AssemblyName System.Drawing

$raiz    = Split-Path -Parent $PSScriptRoot
$destino = Join-Path $raiz "Imagenes\web"

New-Item -ItemType Directory -Force $destino | Out-Null

# Origen (relativo a Imagenes/) -> nombre en la app, con su tamaño y calidad.
# El nombre de destino debe coincidir con la columna `imagen` de la tabla walls.
$fotos = @(
    @{ origen = "Recortadas\SprayWall_p.JPG"; destino = "spraywall.jpg";      maxLado = 2400; calidad = 82L }
    @{ origen = "Recortadas\Muro0º_p.JPG";    destino = "muro-0.jpg";         maxLado = 2400; calidad = 82L }
    @{ origen = "Recortadas\Muro5º_p.JPG";    destino = "muro-5.jpg";         maxLado = 2400; calidad = 82L }
    @{ origen = "Recortadas\Muro15º_p.JPG";   destino = "muro-15.jpg";        maxLado = 2400; calidad = 82L }
    @{ origen = "PanoSprayBIG.jpg";           destino = "panoramica-big.jpg"; maxLado = 8000; calidad = 92L }
)

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
         Where-Object { $_.MimeType -eq 'image/jpeg' }

foreach ($foto in $fotos) {
    $rutaOrigen = Join-Path (Join-Path $raiz "Imagenes") $foto.origen
    if (-not (Test-Path $rutaOrigen)) {
        Write-Warning ("No encuentro {0}, lo salto." -f $foto.origen)
        continue
    }

    $img = [System.Drawing.Image]::FromFile($rutaOrigen)
    try {
        # Reescala por el lado mayor, conservando la proporción original.
        $escala = $foto.maxLado / [Math]::Max($img.Width, $img.Height)
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
                [System.Drawing.Imaging.Encoder]::Quality, $foto.calidad)

            $rutaDestino = Join-Path $destino $foto.destino
            $bmp.Save($rutaDestino, $codec, $ep)

            $kb = [math]::Round((Get-Item $rutaDestino).Length / 1KB)
            Write-Output ("{0,-26} -> {1,-20} {2}x{3}  {4} KB" -f $foto.origen, $foto.destino, $ancho, $alto, $kb)
        }
        finally { $g.Dispose(); $bmp.Dispose() }
    }
    finally { $img.Dispose() }
}

Write-Output ""
Write-Output "Listo. Sube los archivos de Imagenes/web/ a public/walls/ en el proyecto de Lovable."
Write-Output "Recuerda: si cambia el encuadre, los bloques ya guardados de ese muro quedan descolocados."
