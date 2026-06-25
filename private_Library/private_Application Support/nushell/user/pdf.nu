def "--pdf quality" [] {
  ["screen", "ebook", "printer", "prepress", "default"]
}

# compress a .pdf using ghostscript: pdf compress input output [quality]
export def "pdf compress" [
  input: string
  output: string
  quality: string@"--pdf quality" = "ebook"
] {
  ^gs -q -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dSAFER $"(-dPDFSETTINGS=/($quality))" -dCompatibilityLevel=1.4 $"(-sOutputFile=($output))" $input
}

# ocr, compress, auto-rotate and deskew a .pdf file using ocrmypdf: "pdf ocr" file (in-place)
export def "pdf ocr" [file: string] {
  ^ocrmypdf -l 'deu+por' --rotate-pages --deskew --optimize 3 --clean --clean-final --unpaper-args '--layout single --no-blackfilter --no-grayfilter' --tesseract-timeout 0 $file $file
}
