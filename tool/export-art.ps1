<#
.SYNOPSIS
  Exports the actor decks under art/ to PNG frames, through PowerPoint.

.DESCRIPTION
  The PowerPoint route of tool/export_art.py: needs Windows with PowerPoint
  installed, and nothing else. For every art/<actor>_<state>.pptx it exports
  the one grouped shape on each slide to
  assets/images/<actor>_<state>_NNN.png at 512 x 512 on a transparent
  background -- the "Save as Picture" route of docs/art-pipeline.md, without
  the clicking.

  Every deck is checked against the drawing rules first, and nothing is
  written if any of them breaks one: a slide must hold exactly one top-level
  shape, and it must be a group. A sequence's old frames are deleted before
  its new ones are written, so a removed slide leaves no stale frame behind.

  The launcher icon is not exported here: tool/export_art.py turns it into
  the platforms' icon files.

  Run from anywhere:

    powershell -ExecutionPolicy Bypass -File tool\export-art.ps1
    powershell -ExecutionPolicy Bypass -File tool\export-art.ps1 art\hero_walk.pptx

.NOTES
  Written without PowerPoint to hand, so check the first few files it writes
  before trusting a whole run (and say so in an issue if it needs fixing).
#>
param(
  # Decks to export. Every actor deck in art/ when left out.
  [string[]] $Decks
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$art = Join-Path $root 'art'
$images = Join-Path $root 'assets\images'
$deckName = '^[a-z0-9_]+_(idle|walk|hit|die|cheer)(_(s|se|e|ne|n))?$'

$msoGroup = 6          # MsoShapeType.msoGroup
$ppShapeFormatPNG = 2  # PpShapeFormat.ppShapeFormatPNG
$msoTrue = -1
$msoFalse = 0

if ($Decks) {
  $files = $Decks | ForEach-Object { Get-Item (Resolve-Path $_) }
} else {
  $files = Get-ChildItem $art -Filter '*.pptx' | Where-Object { $_.BaseName -ne 'launcher_icon' } | Sort-Object Name
}

$powerPoint = New-Object -ComObject PowerPoint.Application
try {
  # Opens a deck read-only and without a window.
  function Open-Deck($file) {
    $powerPoint.Presentations.Open($file.FullName, $msoTrue, $msoFalse, $msoFalse)
  }

  # Every deck is checked before any file is touched.
  foreach ($file in $files) {
    if ($file.BaseName -notmatch $deckName) {
      throw "$($file.Name): expected <actor>_<state>.pptx (see docs/art-pipeline.md)"
    }
    $deck = Open-Deck $file
    try {
      if ($deck.Slides.Count -eq 0) {
        throw "$($file.Name): no slides"
      }
      foreach ($slide in $deck.Slides) {
        $count = $slide.Shapes.Count
        if ($count -ne 1) {
          throw "$($file.Name), slide $($slide.SlideIndex): $count top-level shapes. Group each pose into one shape (select all, Ctrl+G)."
        }
        if ($slide.Shapes.Item(1).Type -ne $msoGroup) {
          throw "$($file.Name), slide $($slide.SlideIndex): the pose is not a group."
        }
      }
    } finally {
      $deck.Close()
    }
  }

  New-Item -ItemType Directory -Force $images | Out-Null
  foreach ($file in $files) {
    $prefix = "$($file.BaseName)_"
    $stale = '^' + [regex]::Escape($prefix) + '\d{3}\.png$'
    Get-ChildItem $images -Filter '*.png' | Where-Object { $_.Name -match $stale } | Remove-Item

    $deck = Open-Deck $file
    try {
      foreach ($slide in $deck.Slides) {
        $name = '{0}{1:D3}.png' -f $prefix, ($slide.SlideIndex - 1)
        # Each group holds an invisible full-slide square, so the shape's
        # bounds -- what Export writes -- are the slide on every frame.
        $slide.Shapes.Item(1).Export((Join-Path $images $name), $ppShapeFormatPNG, 512, 512)
      }
      '{0,-28} {1} frames' -f $file.Name, $deck.Slides.Count
    } finally {
      $deck.Close()
    }
  }
} finally {
  $powerPoint.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($powerPoint) | Out-Null
}
