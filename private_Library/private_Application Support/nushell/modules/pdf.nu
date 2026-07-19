use shared/tags.nu [tag_info]

def pdf_quality [] {
  ["screen", "ebook", "printer", "prepress", "default"]
}

def pdf_backup_source [source: string] {
  let backup_dir = mktemp -d
  let backup_path = [$backup_dir $"bkp.($source | path basename)"] | path join

  cp $source $backup_path
  tag_info $"Created source backup in temporary folder: ($backup_path | path expand)"
}

def pdf_compress_with_gs [input: string, output: string, quality: string] {
  let result = do -i { ^gs -q -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dSAFER $"(-dPDFSETTINGS=/($quality))" -dCompatibilityLevel=1.4 $"(-sOutputFile=($output))" $input } | complete

  if $result.exit_code != 0 {
    error make --unspanned { msg: $"Ghostscript compression failed: ($result.stderr | str trim)" }
  }
}

# Compress a .pdf using ghostscript: pdf compress input [output] [quality]
# replaces the input file with the compressed output, if output is not specified
export def "pdf compress" [
  input: string
  output?: string
  quality: string@pdf_quality = "ebook"
] {
  pdf_backup_source $input

  let target = $output | default $input
  if $target == $input {
    let temporary_output = mktemp $"($input).tmp.XXXXXX"
    try {
      pdf_compress_with_gs $input $temporary_output $quality
      mv -f $temporary_output $input
    } catch {|err|
      rm -f $temporary_output
      error make --unspanned { msg: $err.msg }
    }
  } else {
    pdf_compress_with_gs $input $target $quality
  }
}

# OCR, compress, auto-rotate and deskew a .pdf file using ocrmypdf: "pdf ocr" file (in-place)
export def "pdf ocr" [file: string] {
  pdf_backup_source $file
  ^ocrmypdf -l 'deu+por' --rotate-pages --deskew --optimize 3 --clean --clean-final --unpaper-args '--layout single --no-blackfilter --no-grayfilter' --tesseract-timeout 0 $file $file
}
