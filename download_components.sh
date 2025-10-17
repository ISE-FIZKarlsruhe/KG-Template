#!/bin/bash
set -e

COMPONENTSDIR=data/components
REASONER=data/components/reasoner
SRC=ontology/ontology.owl
ONTBASE=https://nfdi.fiz-karlsruhe.de/ontology

mkdir -p "$COMPONENTSDIR" "$REASONER"

echo "📥 Downloading TSV files from Google Sheets..."

declare -A files=(
    [sheet1]=1111111111
    [sheet2]=2222222222
)

for name in "${!files[@]}"; do
    gid="${files[$name]}"
    curl -s -L "https://docs.google.com/spreadsheets/d/e/id/pub?gid=${gid}&single=true&output=tsv" \
        -o "$COMPONENTSDIR/$name.tsv"
    echo "✔️ Downloaded: $name.tsv"
done

echo "⚙️ Running ROBOT merge + explain for each component..."

function run_robot_merge() {
    local INPUTS=$1
    local TEMPLATE=$2
    local OUTPUT=$3
    echo "🔧 Merging to $OUTPUT"
    if ! robot merge --include-annotations true $INPUTS template --template "$TEMPLATE" \
        --prefix "nfdicore: $ONTBASE/" --output "$OUTPUT"; then
        echo "❗ Merge failed for $OUTPUT, retrying with -vvv"
        robot -vvv merge --include-annotations true $INPUTS template --template "$TEMPLATE" \
            --prefix "nfdicore: $ONTBASE/" --output "$OUTPUT"
    fi
}

function run_robot_explain() {
    local INPUT=$1
    local OUTPUT=$2
    echo "🔍 Explaining inconsistencies for $INPUT"
    if ! robot explain --reasoner hermit --input "$INPUT" \
        -M inconsistency --explanation "$OUTPUT"; then
        echo "❗ Explain failed for $INPUT, retrying with -vvv"
        robot -vvv explain --reasoner hermit --input "$INPUT" \
            -M inconsistency --explanation "$OUTPUT"
    fi
}

run_robot_merge "-i $SRC" "$COMPONENTSDIR/sheet1.tsv" "$COMPONENTSDIR/sheet1.owl"
run_robot_merge "-i $SRC -i $COMPONENTSDIR/sheet1.owl" "$COMPONENTSDIR/sheet2.tsv" "$COMPONENTSDIR/sheet2.owl"

echo "✅ All components generated and explained."
