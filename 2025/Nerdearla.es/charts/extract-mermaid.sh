#!/bin/bash
TEMP_DIR=".mermaid_temp"
DOWNLOADS_DIR="downloads"
count=0

for md_file in *.md; do
    [ -f "$md_file" ] || continue
    base_name=$(basename "$md_file" .md)
    echo "Processing $md_file..."
    diagram_num=0
    in_mermaid=0
    mmd_content=""
    
    while IFS= read -r line; do
        if echo "$line" | grep -q "^\`\`\`mermaid"; then
            in_mermaid=1
            mmd_content=""
            continue
        fi
        
        if [ $in_mermaid -eq 1 ]; then
            if echo "$line" | grep -q "^\`\`\`"; then
                diagram_num=$((diagram_num + 1))
                mmd_file="$TEMP_DIR/${base_name}-$(printf "%02d" $diagram_num).mmd"
                echo "$mmd_content" > "$mmd_file"
                svg_file="$DOWNLOADS_DIR/${base_name}-$(printf "%02d" $diagram_num).svg"
                echo "  Converting diagram $diagram_num -> $svg_file"
                if mmdc -i "$mmd_file" -o "$svg_file" -b transparent 2>/dev/null; then
                    count=$((count + 1))
                else
                    echo "  Warning: Failed to convert $mmd_file"
                fi
                in_mermaid=0
                mmd_content=""
            else
                mmd_content="$mmd_content$line"$'
'
            fi
        fi
    done < "$md_file"
    
    if [ $diagram_num -eq 0 ]; then
        echo "  No mermaid diagrams found"
    fi
done

rm -rf "$TEMP_DIR"
echo ""
echo "Total diagrams converted: $count"
