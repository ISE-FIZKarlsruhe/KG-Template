#!/bin/bash
set -e

COMPONENTSDIR=data
VALIDATIONSDIR=data/validation
SRC=ontology/ontology.owl
ONTBASE=https://nfdi.fiz-karlsruhe.de/ontology

mkdir -p "$VALIDATIONSDIR"
rm -f "$COMPONENTSDIR/all_NotReasoned.owl" "$COMPONENTSDIR/all.ttl"

echo "Reasoning ontology"
robot reason \
    --reasoner hermit \
    --input "$SRC" \
    --axiom-generators "SubClass SubDataProperty ClassAssertion EquivalentObjectProperty PropertyAssertion InverseObjectProperties SubObjectProperty" \
    --output "data/components/ontology_reasoned.owl"

echo "Merge OWL components"
robot merge --include-annotations true -i "$SRC" --inputs "data/components/*.owl" --output "$COMPONENTSDIR/all_NotReasoned.owl"

echo "Explanations and inconsistency checks"
robot explain --input "$COMPONENTSDIR/all_NotReasoned.owl" -M inconsistency --explanation "$VALIDATIONSDIR/inconsistency.md"
robot explain --reasoner hermit --input "$SRC" -M inconsistency --explanation "$VALIDATIONSDIR/inconsistency_ontology.md"
robot explain --reasoner hermit --input "$COMPONENTSDIR/all_NotReasoned.owl" -M inconsistency --explanation "$VALIDATIONSDIR/inconsistency_hermit.md"

echo "Reasoning KG, for now no reasoning because of performance issues"
robot merge --include-annotations true -i "$SRC" --inputs "data/components/*.owl" --output "$COMPONENTSDIR/all.ttl"
#robot reason \
#    --reasoner hermit \
#    --input "$COMPONENTSDIR/all_NotReasoned.owl" \
#    --axiom-generators "SubClass ClassAssertion" \
#    --output "$COMPONENTSDIR/all.ttl"


# SHACL validations (with safe failure handling)
for i in 1; do
    echo "Running SHACL validations: shape $i"
    SHAPE_FILE="shapes/shape$i.ttl"
    OUTPUT_FILE="$VALIDATIONSDIR/shape$i.md"
    if ! python3 -m pyshacl -s "$SHAPE_FILE" "$COMPONENTSDIR/all.ttl" > "$OUTPUT_FILE"; then
        echo "SHACL validation for shape$i.ttl failed" >&2
    fi
done


echo "All merge, reasoning, and validation steps completed."