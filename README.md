# Bash Usage Help Generator

Generate clean, self-contained usage help for Bash scripts from
structured comments.

This tool extracts Doxygen-style comments from a `.src.bash` file,
converts them into Markdown, and injects the rendered help directly into
a minified `.bash` script.

The result is a compact, production-ready script that still provides
rich, readable usage help at runtime.

------------------------------------------------------------------------

## Quick Start

``` bash
# Create a source script
cat > example.src.bash <<'EOF'
#!/usr/bin/env bash

## @file example.src.bash
## @brief Example CLI tool
## @details
## Demonstrates usage help generation.
##
while getopts "h" option ; do
  case "$option" in
    h) usage_help ; exit 0 ;; ##- display usage help
  esac
done

printf 'Hello, world\n'
EOF

# Run the tool
bash_usage_help_generator.bash example.src.bash

# Run the generated script
./example.bash -h
```

------------------------------------------------------------------------

## Installation

### Manual Installation

``` bash
git clone https://github.com/wesley-dean/bash_usage_help_generator.git
cd bash_usage_help_generator

chmod +x bash_usage_help_generator.bash

# Optional
cp bash_usage_help_generator.bash ~/bin/
```

Usage:

``` bash
bash_usage_help_generator.bash /path/to/script.src.bash
```

------------------------------------------------------------------------

### Docker-Based Installation

Assumes the image:

    wesleydean/bash_usage_help_generator:latest

#### File-based usage

``` bash
docker run --rm \
  -v "$PWD:/work" \
  wesleydean/bash_usage_help_generator:latest \
  /work/example.src.bash
```

#### STDIN / STDOUT usage

``` bash
cat example.src.bash | \
docker run --rm -i \
  wesleydean/bash_usage_help_generator:latest \
  - > example.bash
```

------------------------------------------------------------------------

## Writing Extractable Comments

The tool parses Doxygen-style comments that begin with `##`.

### Supported tags

-   `@file` → top-level title
-   `@fn` → function title
-   `@brief` → short description
-   `@details` → longer description
-   `@param` → grouped under "Parameters"
-   `@retval` → grouped under "Return values"
-   `@return` → grouped under "Returns"
-   `@par` → section header
-   `@code` / `@endcode` → fenced code block
-   `##-` → inline option descriptions

### Example

``` bash
## @fn example()
## @brief Example function
## @param name the name to use
## @retval 0 success
## @retval 1 failure
```

### Options extraction

``` bash
h) usage_help ;; ##- display usage help
'--help') usage_help ;; ##- display usage help
```

Produces:

``` markdown
## Options

* `-h`: display usage help
* `--help`: display usage help
```

------------------------------------------------------------------------

## Full Example

### Input: `example.src.bash`

``` bash
#!/usr/bin/env bash

## @file example.src.bash
## @brief Example CLI tool
## @details
## This script demonstrates usage help generation.
##
while getopts "h" option ; do
  case "$option" in
    h) usage_help ; exit 0 ;; ##- display usage help
  esac
done

printf 'Hello\n'
```

### Run

``` bash
bash_usage_help_generator.bash example.src.bash
```

### Output: `example.bash` (excerpt)

``` bash
usage_help() {
  cat <<'__BASHLIB_USAGE_HELP__'
## Usage

`example.src.bash` [-h]

# file example.src.bash

## Brief

Example CLI tool

## Details

This script demonstrates usage help generation.

## Options

* `-h`: display usage help
__BASHLIB_USAGE_HELP__
}
```

### Runtime

``` bash
./example.bash -h
```

------------------------------------------------------------------------

## How It Works

1.  Extract Doxygen-style comments using `awk`
2.  Convert to Markdown
3.  Minify the script using `Bash-minifier`
4.  Inject a generated `usage_help()` function
5.  Output:
    -   `build/*.bash` (intermediate)
    -   `./script.bash` (final)

------------------------------------------------------------------------

## Testing

Run the full test suite with:

``` bash
make test
```

------------------------------------------------------------------------

## Acknowledgments

This project uses:

-   Bash Minifier by Love Borgström (Zuzzuc)\
    https://github.com/Zuzzuc/Bash-minifier
