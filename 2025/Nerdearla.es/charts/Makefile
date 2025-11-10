.PHONY: all clean setup export-mermaid convert-svg help

# Directories
DOWNLOADS_DIR := downloads
TEMP_DIR := .mermaid_temp

# Find all markdown files
MD_FILES := $(wildcard *.md)

# Help target
help:
	@echo "Mermaid Export Makefile"
	@echo "======================="
	@echo ""
	@echo "Usage:"
	@echo "  make all            - Export all mermaid diagrams to SVG"
	@echo "  make setup          - Install mermaid-cli if not present"
	@echo "  make convert-svg    - Convert all SVG files to PNG"
	@echo "  make clean          - Remove generated files and temp directory"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - Node.js and npm must be installed"
	@echo "  - mermaid-cli (mmdc) - run 'make setup' to install"
	@echo "  - For SVG to PNG: rsvg-convert (librsvg) or ImageMagick"
	@echo ""

# Default target
all: setup export-mermaid

# Setup mermaid-cli
setup:
	@echo "Checking for mermaid-cli..."
	@if ! command -v mmdc >/dev/null 2>&1; then \
		echo "mermaid-cli not found. Installing..."; \
		npm install -g @mermaid-js/mermaid-cli; \
	else \
		echo "mermaid-cli is already installed."; \
	fi

# Export all mermaid diagrams
export-mermaid: extract-mermaid-script
	@echo "Creating directories..."
	@mkdir -p $(DOWNLOADS_DIR)
	@mkdir -p $(TEMP_DIR)
	@echo "Extracting and converting mermaid diagrams..."
	@chmod +x extract-mermaid.sh
	@./extract-mermaid.sh
	@echo ""
	@echo "Done! SVG files are in $(DOWNLOADS_DIR)/"
	@ls -lh $(DOWNLOADS_DIR)/*.svg 2>/dev/null || echo "No SVG files were generated"

# Create the extraction script
extract-mermaid-script:
	@echo '#!/bin/bash' > extract-mermaid.sh
	@echo 'TEMP_DIR=".mermaid_temp"' >> extract-mermaid.sh
	@echo 'DOWNLOADS_DIR="downloads"' >> extract-mermaid.sh
	@echo 'count=0' >> extract-mermaid.sh
	@echo '' >> extract-mermaid.sh
	@echo 'for md_file in *.md; do' >> extract-mermaid.sh
	@echo '    [ -f "$$md_file" ] || continue' >> extract-mermaid.sh
	@echo '    base_name=$$(basename "$$md_file" .md)' >> extract-mermaid.sh
	@echo '    echo "Processing $$md_file..."' >> extract-mermaid.sh
	@echo '    diagram_num=0' >> extract-mermaid.sh
	@echo '    in_mermaid=0' >> extract-mermaid.sh
	@echo '    mmd_content=""' >> extract-mermaid.sh
	@echo '    ' >> extract-mermaid.sh
	@echo '    while IFS= read -r line; do' >> extract-mermaid.sh
	@echo '        if echo "$$line" | grep -q "^\`\`\`mermaid"; then' >> extract-mermaid.sh
	@echo '            in_mermaid=1' >> extract-mermaid.sh
	@echo '            mmd_content=""' >> extract-mermaid.sh
	@echo '            continue' >> extract-mermaid.sh
	@echo '        fi' >> extract-mermaid.sh
	@echo '        ' >> extract-mermaid.sh
	@echo '        if [ $$in_mermaid -eq 1 ]; then' >> extract-mermaid.sh
	@echo '            if echo "$$line" | grep -q "^\`\`\`"; then' >> extract-mermaid.sh
	@echo '                diagram_num=$$((diagram_num + 1))' >> extract-mermaid.sh
	@echo '                mmd_file="$$TEMP_DIR/$${base_name}-$$(printf "%02d" $$diagram_num).mmd"' >> extract-mermaid.sh
	@echo '                echo "$$mmd_content" > "$$mmd_file"' >> extract-mermaid.sh
	@echo '                svg_file="$$DOWNLOADS_DIR/$${base_name}-$$(printf "%02d" $$diagram_num).svg"' >> extract-mermaid.sh
	@echo '                echo "  Converting diagram $$diagram_num -> $$svg_file"' >> extract-mermaid.sh
	@echo '                if mmdc -i "$$mmd_file" -o "$$svg_file" -b transparent 2>/dev/null; then' >> extract-mermaid.sh
	@echo '                    count=$$((count + 1))' >> extract-mermaid.sh
	@echo '                else' >> extract-mermaid.sh
	@echo '                    echo "  Warning: Failed to convert $$mmd_file"' >> extract-mermaid.sh
	@echo '                fi' >> extract-mermaid.sh
	@echo '                in_mermaid=0' >> extract-mermaid.sh
	@echo '                mmd_content=""' >> extract-mermaid.sh
	@echo '            else' >> extract-mermaid.sh
	@echo '                mmd_content="$$mmd_content$$line"$$'"'"'\n'"'"'' >> extract-mermaid.sh
	@echo '            fi' >> extract-mermaid.sh
	@echo '        fi' >> extract-mermaid.sh
	@echo '    done < "$$md_file"' >> extract-mermaid.sh
	@echo '    ' >> extract-mermaid.sh
	@echo '    if [ $$diagram_num -eq 0 ]; then' >> extract-mermaid.sh
	@echo '        echo "  No mermaid diagrams found"' >> extract-mermaid.sh
	@echo '    fi' >> extract-mermaid.sh
	@echo 'done' >> extract-mermaid.sh
	@echo '' >> extract-mermaid.sh
	@echo 'rm -rf "$$TEMP_DIR"' >> extract-mermaid.sh
	@echo 'echo ""' >> extract-mermaid.sh
	@echo 'echo "Total diagrams converted: $$count"' >> extract-mermaid.sh

# Convert SVG files to PNG
convert-svg:
	@echo "Converting SVG files to PNG..."
	@if ! command -v rsvg-convert >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then \
		echo "Error: Neither rsvg-convert nor ImageMagick is installed."; \
		echo "Install one of them:"; \
		echo "  - macOS: brew install librsvg  (or: brew install imagemagick)"; \
		echo "  - Ubuntu/Debian: sudo apt-get install librsvg2-bin"; \
		exit 1; \
	fi
	@if [ ! -d "$(DOWNLOADS_DIR)" ]; then \
		echo "Error: $(DOWNLOADS_DIR) directory does not exist."; \
		echo "Run 'make all' first to generate SVG files."; \
		exit 1; \
	fi
	@svg_count=$$(ls $(DOWNLOADS_DIR)/*.svg 2>/dev/null | wc -l); \
	if [ $$svg_count -eq 0 ]; then \
		echo "No SVG files found in $(DOWNLOADS_DIR)/"; \
		exit 1; \
	fi
	@converted=0; \
	if command -v rsvg-convert >/dev/null 2>&1; then \
		echo "Using rsvg-convert..."; \
		for svg in $(DOWNLOADS_DIR)/*.svg; do \
			png="$${svg%.svg}.png"; \
			echo "  Converting $$(basename $$svg) -> $$(basename $$png)"; \
			rsvg-convert "$$svg" -o "$$png"; \
			converted=$$((converted + 1)); \
		done; \
	else \
		echo "Using ImageMagick convert..."; \
		for svg in $(DOWNLOADS_DIR)/*.svg; do \
			png="$${svg%.svg}.png"; \
			echo "  Converting $$(basename $$svg) -> $$(basename $$png)"; \
			convert "$$svg" "$$png"; \
			converted=$$((converted + 1)); \
		done; \
	fi; \
	echo ""; \
	echo "Converted $$converted SVG files to PNG"; \
	echo "PNG files are in $(DOWNLOADS_DIR)/"

# Clean generated files
clean:
	@echo "Cleaning up..."
	@rm -rf $(DOWNLOADS_DIR) $(TEMP_DIR) extract-mermaid.sh
	@echo "Done!"
