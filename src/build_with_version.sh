#!/bin/bash
# build_with_version.sh
# Adds core version info to c64.xml, compresses it, and calls the original build.sh

set -e

# build variant
EXT=
if [ "$#" -eq 1 ]; then
    EXT=_$1
fi

# generate version string from git tags
RAW_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo unknown)

# Shorten format: "v0.7-15-g522bfd7-dirty" -> "v0.7+15-522bfd7*"
CORE_VERSION=$(echo "$RAW_VERSION" \
  | sed -E 's/-([0-9]+)-g([0-9a-f]+)/+\1-\2/' \
  | sed 's/-dirty/*/')
echo "Core version: $CORE_VERSION"

SRC_XML=./misc/c64.xml
WORK_XML=./misc/c64_work.xml
WORK_GZ=./misc/c64.xml.gz
DEST_HEX=./misc/c64_xml.hex

# Append <button label="Version: Core ..."/> as the last child of the root <menu>
CORE_VERSION="$CORE_VERSION" python3 - "$SRC_XML" "$WORK_XML" <<'PY'
import os
import sys
import xml.etree.ElementTree as ET

src_path = sys.argv[1]
dst_path = sys.argv[2]
version  = os.environ.get("CORE_VERSION", "unknown")

tree = ET.parse(src_path)
root = tree.getroot()

# Find the root-level <menu> under <config>
menu = root.find("menu")
if menu is None:
    sys.exit("ERROR: /config/menu not found")

# Append the version button as low as possible (last child of root menu)
el = ET.SubElement(menu, "button", {"label": f"Core {version}"})
el.tail = "\n"  # <-- ensures a newline after this tag


tree.write(dst_path, encoding="utf-8", xml_declaration=True)
PY

echo "version string added to c64_work.xml"

# The following is not needed since the conmversion is now done
# automatically during synthesis
# gzip -c -n -f $WORK_XML > $WORK_GZ
# xxd -c1 -p $WORK_GZ > $DEST_HEX

# comment line below for debugging file generation
# rm $WORK_XML $WORK_GZ

# echo "c64_work.xml compressed and converted to c64_xml.hex"

read -n 1 -s -r -p "Press any key to continue..."
echo

# --- Call Original build.sh ---
./build.sh "$@"
