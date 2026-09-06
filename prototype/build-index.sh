#!/bin/sh
# Wraps the artifact-style fragment in a full HTML document as the site root for static hosting (Vercel).
# Run from the repo root after editing prototype/crm-prototype.html:  sh prototype/build-index.sh
set -e
{
  printf '<!doctype html>\n<html lang="en-GB">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n<meta name="color-scheme" content="light dark">\n'
  sed -n '1,/<\/style>/p' prototype/crm-prototype.html
  printf '</head>\n<body>\n'
  sed '1,/<\/style>/d' prototype/crm-prototype.html
  printf '</body>\n</html>\n'
} > index.html
echo "wrote index.html ($(wc -c < index.html) bytes)"
